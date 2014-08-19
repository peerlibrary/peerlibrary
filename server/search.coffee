# TODO: Search for persons as well
Meteor.publish 'search-results', (query, limit) ->
  validateArgument query, NonEmptyString, 'query'
  validateArgument limit, PositiveNumber, 'limit'

  findQuery = createQueryCriteria(query, 'fullText')
  return unless findQuery.$and.length

  @related (person) ->
    restrictedFindQuery = Publication.requireReadAccessSelector person, findQuery

    searchPublish @, 'search-results', query,
      cursor: Publication.documents.find(restrictedFindQuery,
        limit: limit
        fields: Publication.PUBLISH_SEARCH_RESULTS_FIELDS().fields
      )
      added: (id, fields) =>
        fields.hasAbstract = !!fields.abstract
        delete fields.abstract
        fields
      changed: (id, fields) =>
        if 'abstract' of fields
          fields.hasAbstract = !!fields.abstract
          delete fields.abstract
        fields
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: Publication.readAccessPersonFields()
