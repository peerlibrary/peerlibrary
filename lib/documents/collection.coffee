class @Collection extends ReadAccessDocument
  # access: 0 (private, ACCESS.PRIVATE), 1 (public, ACCESS.PUBLIC)
  # readPersons: if private access, list of persons who have read permissions
  # readGroups: if private access, list of groups who have read permissions
  # maintainerPersons: list of persons who have maintainer permissions
  # maintainerGroups: ilist of groups who have maintainer permissions
  # adminPersons: list of persons who have admin permissions
  # adminGroups: ilist of groups who have admin permissions
  # createdAt: timestamp when document was created
  # updatedAt: timestamp of this version
  # authorPerson:
  #   _id: author's person id
  #   slug
  #   givenName
  #   familyName
  #   gravatarHash
  #   user
  #     username
  # authorGroup:
  #   _id: author's group id
  #   slug
  #   name
  # name: the name of the collection
  # slug: unique slug for URL
  # publications: list of
  #   _id: publication's id
  # referencingAnnotations: list of (reverse field from Annotation.references.collections)
  #   _id: annotation id

  @Meta
    name: 'Collection'
    fields: =>
      maintainerPersons: [@ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username']]
      maintainerGroups: [@ReferenceField Group, ['slug', 'name']]
      adminPersons: [@ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username']]
      adminGroups: [@ReferenceField Group, ['slug', 'name']]
      authorPerson: @ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username'], false
      authorGroup: @ReferenceField Group, ['slug', 'name'], false
      slug: @GeneratedField 'self', ['name']
      publications: [@ReferenceField Publication]
      updatedAt: UpdatedAtField 'self', ['authorPerson._id', 'authorGroup._id', 'name', 'publications._id']

  _hasMaintainerAccess: (person) =>
    # User has to be logged in
    return unless person?._id

    # TODO: Implement karma points for public documents

    return true if @authorPerson?._id is person._id

    personGroups = _.pluck person.inGroups, '_id'

    return true if @authorGroup?._id in personGroups

    return true if person._id in _.pluck @maintainerPersons, '_id'

    documentGroups = _.pluck @maintainerGroups, '_id'

    return true if _.intersection(personGroups, documentGroups).length

  @_requireMaintainerAccessConditions: (person, selector) ->
    return [] unless person?._id

    [
      'authorPerson._id': person._id
    ,
      'authorGroup._id':
        $in: _.pluck person.inGroups, '_id'
    ,
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
      authorPerson: 1
      authorGroup: 1
      maintainerPersons: 1
      maintainerGroups: 1

  _hasAdminAccess: (person) =>
    # User has to be logged in
    return unless person?._id

    # TODO: Implement karma points for public documents

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

  @applyDefaultAccess: (personId, document) ->
    document = super

    if personId and personId not in _.pluck document.adminPersons, '_id'
      document.adminPersons ?= []
      document.adminPersons.push
        _id: personId
    if document.authorPerson?._id and document.authorPerson._id not in _.pluck document.adminPersons, '_id'
      document.adminPersons ?= []
      document.adminPersons.push
        _id: document.authorPerson._id
    if document.authorGroup?._id and document.authorGroup._id not in _.pluck document.adminGroups, '_id'
      document.adminGroups ?= []
      document.adminGroups.push
        _id: document.authorGroup._id

    document
