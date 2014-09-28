new PublishEndpoint 'search-persons-groups', (query, except) ->
  except ?= []

  validateArgument 'query', query, NonEmptyString
  validateArgument 'except', except, [DocumentId]

  keywords = (keyword.replace /[-\\^$*+?.()|[\]{}]/g, '\\$&' for keyword in query.split /\s+/)

  findPersonQuery =
    $and: []
    _id:
      $nin: except
  findGroupQuery =
    $and: []
    _id:
      $nin: except

  # TODO: Use some smarter searching with provided query, probably using some real full-text search instead of regex
  for keyword in keywords when keyword
    regex = new RegExp keyword, 'i'
    findPersonQuery.$and.push
      $or: [
        _id: keyword
      ,
        'user.username': regex
      ,
        'user.emails.0.address': regex
      ,
        givenName: regex
      ,
        familyName: regex
      ]
    findGroupQuery.$and.push
      $or: [
        _id: keyword
      ,
        name: regex
      ]

  return unless findPersonQuery.$and.length + findGroupQuery.$and.length

  @related (person) ->
    # We store related fields so that they are available in middlewares.
    @set 'person', person

    restrictedFindGroupQuery = Group.requireReadAccessSelector person, findGroupQuery

    searchPublish @, 'search-persons-groups', query,
      # No need for requireReadAccessSelector because persons are public
      cursor: Person.documents.find findPersonQuery,
        limit: 5
        # TODO: Optimize fields, we do not need all
        fields: Person.PUBLISH_FIELDS().fields
    ,
      cursor: Group.documents.find restrictedFindGroupQuery,
        limit: 5
        # TODO: Optimize fields, we do not need all
        fields: Group.PUBLISH_FIELDS().fields
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: Publication.readAccessPersonFields()
