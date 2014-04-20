# TODO: Search for persons as well
Meteor.publish 'search-results', (query, limit) ->
  check query, NonEmptyString
  check limit, PositiveNumber

  keywords = (keyword.replace /[-\\^$*+?.()|[\]{}]/g, '\\$&' for keyword in query.split /\s+/)

  findQuery =
    $and: []

  # TODO: Use some smarter searching with provided query, probably using some real full-text search instead of regex
  for keyword in keywords when keyword
    findQuery.$and.push
      fullText: new RegExp keyword, 'i'

  return unless findQuery.$and.length

  @related (person) ->
    restrictedFindQuery = Publication.requireReadAccessSelector person, findQuery

    searchPublish @, 'search-results', query,
      cursor: Publication.documents.find(restrictedFindQuery,
        limit: limit
        fields: Publication.PUBLIC_SEARCH_RESULTS_FIELDS().fields
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
