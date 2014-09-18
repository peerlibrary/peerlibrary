# This function wraps search logic. Name and query is whatever you want to be stored into the
# SearchResults document so that it is possible to find it on the client side (by convention,
# name is simply the publish endpoint name and query what was given by the user).

# Results are objects with the following fields:
#   cursor: a queryset cursor with result documents (including any limit)
#   added/changed/removed: callbacks to be called by corresponding observeChanges call on
#                          the cursor a before document is published, to allow preprocessing

# More or less the whole logic is how to publish documents from provided cursors and attach
# information which documents are connected to which search results, including the order of
# documents inside search results (not yet implemented). Optionally, it allows preprocessing
# documents before publishing them.

# Documents from results querysets are published, together with a SearchResult document.
# Published documents get a field searchResult which represents the last search query the
# document is a result for, if any. It contains:
#   _id: id of the query, an _id of the SearchResult object for the query
#   order: order of the result in the search query, lower number means higher (not yet implemented)

# Published SearchResult document contains name and query so that it can be found on the
# client side, and for every given result queryset a count field of how many documents are
# in the queryset if skip and limit are ignored. This allows pagination on the client while
# still knowing how many results there are in total. Count field name is constructed with
# prefix "count" and cursor's collection name.

# TODO: How to influence order of results? Should we have just simply a field?
# TODO: Make sure that searchResult field cannot be stored on the server by accident
@searchPublish = (publish, name, query, results...) ->
  queryId = Random.id()

  initializing = results.length

  counts = []
  resultsHandles = []
  countsHandles = []
  for result, i in results
    do (result, i) ->
      orderMap = {}
      orderList = []

      assertOrder = ->
        assert.equal orderList.length, _.size orderMap
        for orderId, orderIndex in orderList
          assert.equal orderMap[orderId], orderIndex

      counts[i] = 0

      resultsHandles[i] = result.cursor.observeChanges
        addedBefore: (id, fields, before) =>
          if before
            beforeIndex = orderMap[before]

            # Insert
            orderList.splice beforeIndex, 0, id
            orderMap[id] = beforeIndex

            # Reindex all after the insertion point
            for orderId, orderIndex in orderList[(beforeIndex + 1)..]
              orderIndex += beforeIndex + 1
              orderMap[orderId] = orderIndex
              publish.changed result.cursor._cursorDescription.collectionName, orderId,
                searchResult:
                  _id: queryId
                  order: orderIndex

          else # Added at the end
            orderList.push id
            orderMap[id] = orderList.length - 1

          fields.searchResult =
            _id: queryId
            order: orderMap[id]

          fields = result.added id, fields if result.added # Optional preprocessing callback

          publish.added result.cursor._cursorDescription.collectionName, id, fields

          assertOrder()

        changed: (id, fields) =>
          fields = result.changed id, fields if result.changed # Optional preprocessing callback

          publish.changed result.cursor._cursorDescription.collectionName, id, fields unless _.isEmpty fields

        movedBefore: (id, before) =>
          idIndex = orderMap[id]

          # TODO: Can be before null?
          unless before # Moved to the end
            # Remove from the current position
            orderList.splice idIndex, 1
            delete orderMap[id]

            # Reindex all from the deletion point on
            for orderId, orderIndex in orderList[idIndex..]
              orderIndex += idIndex
              orderMap[orderId] = orderIndex
              publish.changed result.cursor._cursorDescription.collectionName, orderId,
                searchResult:
                  _id: queryId
                  order: orderIndex

            # Add at the end
            orderList.push id
            orderMap[id] = orderList.length - 1

            publish.changed result.cursor._cursorDescription.collectionName, id,
              searchResult:
                _id: queryId
                order: orderMap[id]

          else
            beforeIndex = orderMap[before]

            if idIndex is beforeIndex - 1 # Moved to the same position
              assert false
            else if idIndex < beforeIndex # Moved after current position
              # Remove from the current position
              orderList.splice idIndex, 1
              delete orderMap[id]

              # Reindex all from the deletion point to, but excluding the new position (we
              # will reinsert there and push everything afterwards back to the right position)
              for orderId, orderIndex in orderList[idIndex...(beforeIndex - 1)]
                orderIndex += idIndex
                orderMap[orderId] = orderIndex
                publish.changed result.cursor._cursorDescription.collectionName, orderId,
                  searchResult:
                    _id: queryId
                    order: orderIndex

              # Add at the new position
              orderList.splice beforeIndex - 1, 0, id
              orderMap[id] = beforeIndex - 1

              publish.changed result.cursor._cursorDescription.collectionName, id,
                searchResult:
                  _id: queryId
                  order: orderMap[id]

            else if beforeIndex < idIndex # Move before current position
              # Remove from the current position
              orderList.splice idIndex, 1
              delete orderMap[id]

              # Add at the new position
              orderList.splice beforeIndex, 0, id
              orderMap[id] = beforeIndex

              publish.changed result.cursor._cursorDescription.collectionName, id,
                searchResult:
                  _id: queryId
                  order: orderMap[id]

              # Reindex all after the insertion point on, including
              # the old position (to where everything was pushed to)
              for orderId, orderIndex in orderList[(beforeIndex + 1)..idIndex]
                orderIndex += beforeIndex + 1
                orderMap[orderId] = orderIndex
                publish.changed result.cursor._cursorDescription.collectionName, orderId,
                  searchResult:
                    _id: queryId
                    order: orderIndex

            else # Moved to the same position
              assert false

          assertOrder()

        removed: (id) =>
          result.removed id if result.removed # Optional preprocessing callback

          publish.removed result.cursor._cursorDescription.collectionName, id

          idIndex = orderMap[id]

          # Remove
          orderList.splice idIndex, 1
          delete orderMap[id]

          # Reindex all from the deletion point on
          for orderId, orderIndex in orderList[idIndex..]
            orderIndex += idIndex
            orderMap[orderId] = orderIndex
            publish.changed result.cursor._cursorDescription.collectionName, orderId,
              searchResult:
                _id: queryId
                order: orderIndex

          assertOrder()

      # For counting we want only _id field and no skip or limit restrictions
      result.cursor._cursorDescription.options.fields =
        _id: 1
      delete result.cursor._cursorDescription.options.skip
      delete result.cursor._cursorDescription.options.limit

      countsHandles[i] = result.cursor.observeChanges
        added: (id, fields) =>
          counts[i]++
          if initializing is 0
            change = {}
            change["count#{ result.cursor._cursorDescription.collectionName }"] = counts[i]
            publish.changed 'SearchResults', queryId, change

        removed: (id) =>
          counts[i]--
          change = {}
          change["count#{ result.cursor._cursorDescription.collectionName }"] = counts[i]
          publish.changed 'SearchResults', queryId, change

      initializing--

  assert.equal initializing, 0

  initializedCounts =
    name: name
    query: query
  for result, i in results
    initializedCounts["count#{ result.cursor._cursorDescription.collectionName }"] = counts[i]

  publish.added 'SearchResults', queryId, initializedCounts

  publish.ready()

  publish.onStop ->
    for handle, i in resultsHandles
      handle?.stop()
      resultsHandles[i] = null
    for handle, i in countsHandles
      handle?.stop()
      countsHandles[i] = null

@createQueryCriteria = (query, field) ->
  queryCriteria =
    $and: []

  console.log field
  keywords = (keyword.replace /[-\\^$*+?.()|[\]{}]/g, '\\$&' for keyword in query.split /\s+/)

  # TODO: Use some smarter searching with provided query, probably using some real full-text search instead of regex
  for keyword in keywords when keyword
    fieldCriteria = {}
    fieldCriteria[field] = new RegExp keyword, 'i'
    queryCriteria.$and.push fieldCriteria

  queryCriteria
