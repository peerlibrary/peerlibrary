class @Collection extends AccessDocument
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

  hasMaintainerAccess: (person) =>
    # User has to be logged in
    return false unless person?._id

    return true if person.isAdmin

    # Unknown access, we prevent access to the document
    # TODO: Should we log this?
    return false unless @access in [Collection.ACCESS.PUBLIC, Collection.ACCESS.PRIVATE]

    # TODO: Implement maintainer karma points for public documents

    return true if @authorPerson?._id is person._id

    personGroups = _.pluck person.inGroups, '_id'

    return true if @authorGroup?._id in personGroups

    return true if person._id in _.pluck @maintainerPersons, '_id'

    documentGroups = _.pluck @maintainerGroups, '_id'

    return true if _.intersection(personGroups, documentGroups).length

    # Admins are maintainers automatically

    # TODO: Implement admin karma points for public documents

    return true if person._id in _.pluck @adminPersons, '_id'

    documentGroups = _.pluck @adminGroups, '_id'

    return true if _.intersection(personGroups, documentGroups).length

    return false

  @requireMaintainerAccessSelector: (person, selector) ->
    unless person?._id
      # Returns a selector which does not match anything
      return _id:
        $in: []

    return selector if person.isAdmin

    # To not modify input
    selector = EJSON.clone selector

    # We use $and to not override any existing selector field
    selector.$and = [] unless selector.$and

    accessConditions = [
      'authorPerson._id': person._id
    ,
      'authorGroup._id':
        $in: _.pluck person.inGroups, '_id'
    ,
      'maintainerPersons._id': person._id
    ,
      'maintainerGroups._id':
        $in: _.pluck person.inGroups, '_id'
    , # Admins are maintainers automatically
      'adminPersons._id': person._id
    ,
      'adminGroups._id':
        $in: _.pluck person.inGroups, '_id'
    ]

    selector.$and.push
      access:
        $in: [Collection.ACCESS.PUBLIC, Collection.ACCESS.PRIVATE]
      $or: accessConditions
    selector

  hasAdminAccess: (person) =>
    # User has to be logged in
    return false unless person?._id

    return true if person.isAdmin

    # Unknown access, we prevent access to the document
    # TODO: Should we log this?
    return false unless @access in [Collection.ACCESS.PUBLIC, Collection.ACCESS.PRIVATE]

    # TODO: Implement karma points for public publications

    return true if person._id in _.pluck @adminPersons, '_id'

    personGroups = _.pluck person.inGroups, '_id'
    documentGroups = _.pluck @adminGroups, '_id'

    return true if _.intersection(personGroups, documentGroups).length

    return false

  @requireAdminAccessSelector: (person, selector) ->
    unless person?._id
      # Returns a selector which does not match anything
      return _id:
        $in: []

    return selector if person.isAdmin

    # To not modify input
    selector = EJSON.clone selector

    # We use $and to not override any existing selector field
    selector.$and = [] unless selector.$and

    accessConditions = [
      'adminPersons._id': person._id
    ,
      'adminGroups._id':
        $in: _.pluck person.inGroups, '_id'
    ]

    selector.$and.push
      access:
        $in: [Collection.ACCESS.PUBLIC, Collection.ACCESS.PRIVATE]
      $or: accessConditions
    selector

  hasRemoveAccess: (person) =>
    @hasMaintainerAccess person

  @requireRemoveAccessSelector: (person, selector) ->
    @requireMaintainerAccessSelector person, selector

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
