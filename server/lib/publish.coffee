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
        handleDocuments = null
        collectionName = null

        publishDocuments = (relatedDocuments) ->
          initializing = true
          initializedDocuments = []

          oldHandleDocuments = handleDocuments
          newCursor = publishFunction relatedDocuments...
          unless newCursor
            handleDocuments = null
          else
            collectionName = newCursor._cursorDescription.collectionName unless collectionName
            assert.equal newCursor._cursorDescription.collectionName, collectionName

            handleDocuments = newCursor.observeChanges
              added: (id, fields) ->
                initializedDocuments.push id if initializing

                return if currentDocuments[id]
                currentDocuments[id] = true

                publish.added collectionName, id, fields

              changed: (id, fields) ->
                return if not currentDocuments[id]

                publish.changed collectionName, id, fields

              removed: (id) ->
                return if not currentDocuments[id]
                delete currentDocuments[id]

                publish.removed collectionName, id

          initializing = false

          # We stop the handle after we established the new handle,
          # so that any possible changes hapenning in the meantime
          # were still processed by the old handle
          oldHandleDocuments.stop() if oldHandleDocuments
          oldHandleDocuments = null

          # And then we remove those which are not published anymore
          for id in _.difference _.keys(currentDocuments), initializedDocuments
            delete currentDocuments[id]
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
          handleDocuments.stop() if handleDocuments
          handleDocuments = null

      func.apply publish, args
