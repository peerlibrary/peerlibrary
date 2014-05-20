class @Group extends ReadAccessDocument
  # access: 0 (private, ACCESS.PRIVATE), 1 (public, ACCESS.PUBLIC)
  # readPersons: if private access, list of persons who have read permissions
  # readGroups: if private access, list of groups who have read permissions
  # maintainerPersons: list of persons who have maintainer permissions
  # maintainerGroups: ilist of groups who have maintainer permissions
  # adminPersons: list of persons who have admin permissions
  # adminGroups: ilist of groups who have admin permissions
  # createdAt: timestamp when document was created
  # updatedAt: timestamp of this version
  # slug: slug for URL
  # name: name of the group
  # members: list of people in the group
  # membersCount: number of people in the group
  # referencingAnnotations: list of (reverse field from Annotation.references.groups)
  #   _id: annotation id
  # searchResult (client only): the last search query this document is a result for, if any, used only in search results
  #   _id: id of the query, an _id of the SearchResult object for the query
  #   order: order of the result in the search query, lower number means higher

  @Meta
    name: 'Group'
    fields: =>
      maintainerPersons: [@ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username']]
      maintainerGroups: [@ReferenceField 'self', ['slug', 'name']]
      adminPersons: [@ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username']]
      adminGroups: [@ReferenceField 'self', ['slug', 'name']]
      slug: @GeneratedField 'self', ['name']
      members: [@ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username'], true, 'inGroups']
      membersCount: @GeneratedField 'self', ['members']

  _hasReadAccess: (person) =>
    access = super
    return access if access is true or access is false

    personGroups = _.pluck person.inGroups, '_id'

    return true if @_id in personGroups

  @_requireReadAccessConditions: (person) ->
    conditions = super
    return conditions unless _.isArray conditions

    if person?._id
      conditions.push
        _id:
          $in: _.pluck person.inGroups, '_id'

    conditions

  _hasMaintainerAccess: (person) =>
    # User has to be logged in
    return unless person?._id

    # TODO: Implement karma points for public documents

    return true if person._id in _.pluck @maintainerPersons, '_id'

    personGroups = _.pluck person.inGroups, '_id'
    documentGroups = _.pluck @maintainerGroups, '_id'

    return true if _.intersection(personGroups, documentGroups).length

  @_requireMaintainerAccessConditions: (person) ->
    return [] unless person?._id

    [
      'maintainerPersons._id': person._id
    ,
      'maintainerGroups._id':
        $in: _.pluck person.inGroups, '_id'
    ]

  @maintainerAccessPersonFields: ->
    fields = super
    _.extend fields,
      inGroups: 1

  @maintainerAccessSelfFields: ->
    fields = super
    _.extend fields,
      maintainerPersons: 1
      maintainerGroups: 1

  _hasAdminAccess: (person) =>
    # User has to be logged in
    return unless person?._id

    return true if person._id in _.pluck @adminPersons, '_id'

    personGroups = _.pluck person.inGroups, '_id'
    documentGroups = _.pluck @adminGroups, '_id'

    return true if _.intersection(personGroups, documentGroups).length

  @_requireAdminAccessConditions: (person) ->
    return [] unless person?._id

    [
      'adminPersons._id': person._id
    ,
      'adminGroups._id':
        $in: _.pluck person.inGroups, '_id'
    ]

  @adminAccessPersonFields: ->
    fields = super
    _.extend fields,
      inGroups: 1

  @adminAccessSelfFields: ->
    fields = super
    _.extend fields,
      adminPersons: 1
      adminGroups: 1

  hasRemoveAccess: (person) =>
    @hasAdminAccess person

  @requireRemoveAccessSelector: (person, selector) ->
    @requireAdminAccessSelector person, selector

  @applyDefaultAccess: (personId, document) ->
    document = super

    if personId and personId not in _.pluck document.adminPersons, '_id'
      document.adminPersons ?= []
      document.adminPersons.push
        _id: personId

    document
