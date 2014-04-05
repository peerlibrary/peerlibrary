unless originalPublish
  originalPublish = Meteor.publish

  Meteor.publish = (name, func) ->
    originalPublish name, (args...) ->
      publish = @

      # Not the pretiest code in existence, we are redoing the query for each publish call.
      # It would be much better if we could rerun this only when userId is invalidated and
      # store personId in the current method invocation context and then just retrieve it
      # here.
      # TODO: Optimize this code
      person = Person.documents.findOne
        'user._id': @userId
      ,
        _id: 1

      publish.personId = person?._id or null

      # TODO: Should we use try/except around the code so that if there is any exception we stop handlers?
      publish.related = (publishFunction, related...) ->
        # There are moments when two observes are observing mostly similar list
        # of document ids so it could happen that one is changing or removing
        # a document just while the other one is adding, so we are making sure
        # using currentDocuments variable that we have a consistent view of the
        # documents we published
        currentDocuments = {}
        relatedPublish = null

        publishDocuments = (relatedDocuments) ->
          assert relatedDocuments.length

          initializing = true
          initializedDocuments = {}

          oldRelatedPublish = relatedPublish

          relatedPublish = publish._recreate()
          relatedPublish.personId = publish.personId
          relatedPublish.related = publish.related

          relatedPublishAdded = relatedPublish.added
          relatedPublishChanged = relatedPublish.changed
          relatedPublishRemoved = relatedPublish.removed

          _.extend relatedPublish,
            added: (collectionName, id, fields) ->
              currentDocuments[collectionName] ?= {}
              initializedDocuments[collectionName] ?= []

              initializedDocuments[collectionName].push id if initializing

              return if currentDocuments[collectionName][id]
              currentDocuments[collectionName][id] = true

              relatedPublishAdded.call @, collectionName, id, fields

            changed: (collection, id, fields) ->
              currentDocuments[collectionName] ?= {}
              initializedDocuments[collectionName] ?= []

              return if not currentDocuments[collectionName][id]

              relatedPublishChanged.call @, collectionName, id, fields

            removed: (collection, id) ->
              currentDocuments[collectionName] ?= {}
              initializedDocuments[collectionName] ?= []

              return if not currentDocuments[collectionName][id]
              delete currentDocuments[collectionName][id]

              relatedPublishRemoved.call @, collectionName, id

            ready: -> # Noop

            stop: (onlyRelated) ->
              @_deactivate()
              publish.stop() unless onlyRelated

          if Package['audit-argument-checks']
            relatedPublish._handler = (args...) ->
              # Related parameters are trusted
              check arg, Match.Any for arg in args
              publishFunction args...
          else
            relatedPublish._handler = publishFunction
          relatedPublish._params = relatedDocuments
          relatedPublish._runHandler()

          initializing = false

          # We call stop after we established the new related publish,
          # so that any possible changes hapenning in the meantime
          # were still processed by the old related publish
          oldRelatedPublish.stop true if oldRelatedPublish
          oldRelatedPublish = null

          # And then we remove those which are not published anymore
          for collectionName, documents of currentDocuments
            for id in _.difference _.keys(documents), initializedDocuments[collectionName]
              delete documents[id]
              publish.removed collectionName, id

        currentRelatedDocuments = []
        handleRelatedDocuments = []

        relatedInitializing = related.length

        for r, i in related
          do (r, i) ->
            currentRelatedDocuments[i] = null
            handleRelatedDocuments[i] = r.observe
              added: (doc) ->
                # There should be only one document with the id at every given moment
                assert.equal currentRelatedDocuments[i], null

                currentRelatedDocuments[i] = doc
                publishDocuments currentRelatedDocuments if relatedInitializing is 0

              changed: (newDoc, oldDoc) ->
                # Document should already be added
                assert.equal currentRelatedDocuments[i]?._id, newDoc._id

                currentRelatedDocuments[i] = newDoc

                # We are checking relatedInitializing even here because it could happen that this is triggered why other related documents are still being initialized
                publishDocuments currentRelatedDocuments if relatedInitializing is 0

              removed: (oldDoc) ->
                # We cannot remove the document if we never added the document before
                assert.equal currentRelatedDocuments[i]?._id, oldDoc._id

                currentRelatedDocuments[i] = null

                # We are checking relatedInitializing even here because it could happen that this is triggered why other related documents are still being initialized
                publishDocuments currentRelatedDocuments if relatedInitializing is 0

          # We initialized this related document
          relatedInitializing--

        assert.equal relatedInitializing, 0

        # We call publishDocuments for the first time
        publishDocuments currentRelatedDocuments

        publish.ready()

        publish.onStop ->
          for handle, i in handleRelatedDocuments
            handle.stop() if handle
            handleRelatedDocuments[i] = null
          relatedPublish.stop true if relatedPublish
          relatedPublish = null

      func.apply publish, args
