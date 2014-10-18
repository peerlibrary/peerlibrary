# TODO: Search for persons as well
searchResults = new PublishEndpoint 'search-results', (query, limit) ->
  validateArgument 'query', query, NonEmptyString
  validateArgument 'limit', limit, PositiveNumber

  if query
    fullQuery = 'title:' + query  + ' OR fullText:' + query  
    ESQuery = { index: 'publication', q: fullQuery, size: 50 }
    esId = getIdsFromES ESQuery
    findQuery = esId[0]
    order_map = esId[1]
    # console.log findQuery
  else
    findQuery = {}

  @related (person) ->
    # We store related fields so that they are available in middlewares.
    @set 'person', person

    restrictedFindQuery = Publication.requireReadAccessSelector person, findQuery

    searchPublishES @, 'search-results', query, order_map,
      cursor: Publication.documents.find restrictedFindQuery,
        limit: limit
        fields: Publication.PUBLISH_SEARCH_RESULTS_FIELDS().fields
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: Publication.readAccessPersonFields()

searchResults.use new HasAbstractMiddleware()

searchResults.use new HasCachedIdMiddleware()

searchResults.use new LimitImportingMiddleware()
