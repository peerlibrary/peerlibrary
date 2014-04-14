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
      counts[i] = 0

      resultsHandles[i] = result.cursor.observeChanges
        added: (id, fields) =>
          fields.searchResult =
            _id: queryId
            # TODO: Implement
            order: 1

          fields = result.added id, fields if result.added

          publish.added result.cursor._cursorDescription.collectionName, id, fields

        changed: (id, fields) =>
          # TODO: Maybe order changed now?

          fields = result.changed id, fields if result.changed

          publish.changed result.cursor._cursorDescription.collectionName, id, fields unless _.isEmpty fields

        removed: (id) =>
          result.removed id if result.removed

          # We remove from the search results and leave to some other publish function to remove whole document
          publish.changed result.cursor._cursorDescription.collectionName, id, searchResult: undefined

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
      handle.stop() if handle
      resultsHandles[i] = null
    for handle, i in countsHandles
      handle.stop() if handle
      countsHandles[i] = null
