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
        relatedPublish = null

        publishDocuments = (relatedDocuments) ->
          assert relatedDocuments.length

          oldRelatedPublish = relatedPublish

          relatedPublish = publish._recreate()
          relatedPublish.personId = publish.personId
          relatedPublish.related = publish.related

          relatedPublish.ready = -> # Noop

          relatedPublish.stop = (onlyRelated) ->
            # We only deactivate, but not stop subscription
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

          return unless oldRelatedPublish

          # We remove those which are not published anymore
          for collectionName in _.difference _.keys(oldRelatedPublish._documents), _.keys(relatedPublish._documents)
            for id in _.difference _.keys(oldRelatedPublish._documents[collectionName] or {}), _.keys(relatedPublish._documents[collectionName] or {})
              oldRelatedPublish.removed collectionName, id

          oldRelatedPublish.stop true
          oldRelatedPublish = null

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
