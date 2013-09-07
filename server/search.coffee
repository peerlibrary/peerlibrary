SEARCH_PROPOSE_LIMIT = 4

Meteor.methods
  # "key" is parsed user-provided string serving as keyword
  # "filter" is internal filter field so that "value" can be mapped to filters
  'search-propose': (query) ->
    # TODO: For now we just ignore query, we should do something smart with it
    proposals = Publications.find(
      cached: true,
      processed: true
    ,
      limit: SEARCH_PROPOSE_LIMIT - 1
    ).map (publication) ->
      [
        key: "publication titled"
        filter: "title"
        value: publication.title
      ,
        key: "by"
        filter: "authors"
        value: "#{ publication.authors[0].lastName } et al."
      ]
    proposals.push [
      key: ""
      filter: "contains"
      value: query
    ]
    proposals

Meteor.publish 'search-results', (query, limit) ->
  if not query
    return

  if _.isString(query)
    # TODO: We should parse it here in a same way as we would parse in search-propose, and take the best interpretation
    realQuery = [
      key: ""
      filter: "contains"
      value: query
    ]
  else
    # TODO: Validate?
    realQuery = query

  findQuery =
    title: new RegExp(query, 'i')
    cached: true
    processed: true

  queryId = Random.id()

  # TODO: Do some real seaching
  # TODO: How to influence order of results? Should we have just simply a field?
  # TODO: Escape query in regexp
  # TODO: Make sure that searchResult field cannot be stored on the server by accident
  resultsHandle = Publications.find(findQuery,
    limit: limit
    fields: _.pick Publication.publicFields().fields, Publication.publicSearchResultFields()
  ).observeChanges
    added: (id, fields) =>
      # TODO: Check if for second query with same id, is searchResult field updated or is the old one kept on the client?
      fields.searchResult =
        id: queryId
        # TODO: Implement
        order: 1

      @added 'Publications', id, fields

    changed: (id, fields) =>
      # TODO: Maybe order changed now?
      # We just pass on the changes
      @changed 'Publications', id, fields

    removed: (id) =>
      # We remove from the search results and leave to some other publish function to remove whole document
      @changed 'Publications', id, searchResult: undefined

  count = 0
  countInitializing = true

  countHandle = Publications.find(findQuery,
    fields:
      _id: 1
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
    countPeople: 0 # TODO: Implement people counting

  @ready()

  @onStop =>
    @removed 'SearchResults', queryId

    resultsHandle.stop()
    countHandle.stop()

Meteor.publish 'search-available', ->
  searchResultsId = Random.id()
  count = 0
  minPublicationDate = null
  maxPublicationDate = null
  initializing = true

  handle = Publications.find(
    cached: true
    processed: true
  ,
    fields:
      _id: 1
      created: 1
  ).observeChanges
    added: (id, fields) =>
      count++

      created = moment.utc fields.created

      changed =
        countPublications: count

      if not minPublicationDate or created < minPublicationDate
        minPublicationDate = created
        changed.minPublicationDate = minPublicationDate

      if not maxPublicationDate or created > maxPublicationDate
        maxPublicationDate = created
        changed.maxPublicationDate = maxPublicationDate

      @changed 'SearchResults', searchResultsId, changed if !initializing

    changed: (id, fields) =>
      return unless fields.created

      created = moment.utc fields.created

      changed = {}
      changed.minPublicationDate = created.toDate() if created < minPublicationDate
      changed.maxPublicationDate = created.toDate() if created > maxPublicationDate

      @changed 'SearchResults', searchResultsId, changed if changed

    removed: (id) =>
      count--
      @changed 'SearchResults', searchResultsId,
        countPublications: count

      # We ignore removed publications for minPublicationDate and maxPublicationDate
      # This much simplifies the code and there is not really a big drawback because of this

  initializing = false

  @added 'SearchResults', searchResultsId,
    query: null
    countPublications: count
    countPeople: 0 # TODO: Implement people counting
    minPublicationDate: minPublicationDate?.toDate()
    maxPublicationDate: maxPublicationDate?.toDate()

  @ready()

  @onStop =>
    @removed 'SearchResults', searchResultsId

    handle.stop()
