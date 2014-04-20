class @Collection extends AccessDocument
  # access: 0 (private, ACCESS.PRIVATE), 1 (public, ACCESS.PUBLIC)
  # readPersons: if private access, list of persons who have read permissions
  # readGroups: if private access, list of groups who have read permissions
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
      slug: @GeneratedField 'self', ['name']
      authorPerson: @ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username'], false
      authorGroup: @ReferenceField Group, ['slug', 'name'], false
      publications: [@ReferenceField Publication]

  hasMaintainerAccess: (person) =>
    # User has to be logged in
    return false unless person?._id

    return true if person.isAdmin

    # Unknown access, we prevent access to the document
    # TODO: Should we log this?
    return false unless @access in [Collection.ACCESS.PUBLIC, Collection.ACCESS.PRIVATE]

    # TODO: Implement karma points for public documents

    return true if @authorPerson?._id is person._id

    personGroups = _.pluck person.inGroups, '_id'

    return true if @authorGroup?._id in personGroups

    return true if person._id in _.pluck @maintainerPersons, '_id'

    documentGroups = _.pluck @maintainerGroups, '_id'

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
