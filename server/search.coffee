# TODO: Search for persons as well
searchResults = new PublishEndpoint 'search-results', (query, limit) ->
  validateArgument 'query', query, NonEmptyString
  validateArgument 'limit', limit, PositiveNumber

  findQuery = createQueryCriteria query, 'fullText'
  return unless findQuery.$and.length

  @related (person) ->
    # We store related fields so that they are available in middlewares.
    @set 'person', person

    restrictedFindQuery = Publication.requireReadAccessSelector person, findQuery

    searchPublish @, 'search-results', query,
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
