Meteor.publish 'search-results', (query, limit) ->
  check query, String
  check limit, PositiveNumber

  return unless query

  keywords = (keyword.replace /[-\\^$*+?.()|[\]{}]/g, '\\$&' for keyword in query.split /\s+/)

  findQuery =
    $and: []
    processed:
      $exists: true

  for keyword in keywords when keyword
    findQuery.$and.push
      fullText: new RegExp keyword, 'i'

  return unless findQuery.$and.length

  queryId = Random.id()

  # TODO: Use some smarter searching with provided query, probably using some real full-text search instead of regex
  # TODO: How to influence order of results? Should we have just simply a field?
  # TODO: Make sure that searchResult field cannot be stored on the server by accident
  resultsHandle = Publication.documents.find(findQuery,
    limit: limit
    fields: _.pick Publication.PUBLIC_FIELDS().fields, Publication.PUBLIC_SEARCH_RESULTS_FIELDS()
  ).observeChanges
    added: (id, fields) =>
      # TODO: Check if for second query with same id, is searchResult field updated or is the old one kept on the client?
      fields.searchResult =
        _id: queryId
        # TODO: Implement
        order: 1

      fields.hasAbstract = !!fields.abstract
      delete fields.abstract

      @added 'Publications', id, fields

    changed: (id, fields) =>
      # TODO: Maybe order changed now?
      # We just pass on the changes

      if 'abstract' of fields
        fields.hasAbstract = !!fields.abstract
        delete fields.abstract

      @changed 'Publications', id, fields

    removed: (id) =>
      # We remove from the search results and leave to some other publish function to remove whole document
      @changed 'Publications', id, searchResult: undefined

  count = 0
  countInitializing = true

  countHandle = Publication.documents.find(findQuery,
    fields:
      _id: 1 # We want only id
  ).observeChanges
    added: (id) =>
      count++
      if !countInitializing
        @changed 'SearchResults', queryId,
          countPublications: count

    removed: (id) =>
      count--
      @changed 'SearchResults', queryId,
        countPublications: count

  countInitializing = false

  @added 'SearchResults', queryId,
    query: query
    countPublications: count
    countPersons: 0 # TODO: Implement people counting

  @ready()

  @onStop =>
    @removed 'SearchResults', queryId

    resultsHandle.stop()
    countHandle.stop()
