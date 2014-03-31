# TODO: Search for persons as well
Meteor.publish 'search-results', (query, limit) ->
  check query, String
  check limit, PositiveNumber

  return unless query

  keywords = (keyword.replace /[-\\^$*+?.()|[\]{}]/g, '\\$&' for keyword in query.split /\s+/)

  findQuery =
    $and: []

  # TODO: Use some smarter searching with provided query, probably using some real full-text search instead of regex
  for keyword in keywords when keyword
    findQuery.$and.push
      fullText: new RegExp keyword, 'i'

  return unless findQuery.$and.length

  # TODO: Not reactive, can we make it?
  person = Person.documents.findOne
    _id: @personId
  ,
    fields:
      # _id field is implicitly added
      isAdmin: 1
      inGroups: 1
      library: 1

  findQuery = Publication.requireReadAccessSelector person, findQuery

  searchPublish @, 'search-results', query,
    cursor: Publication.documents.find(findQuery,
      limit: limit
      fields: _.pick Publication.PUBLIC_FIELDS().fields, Publication.PUBLIC_SEARCH_RESULTS_FIELDS()
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
