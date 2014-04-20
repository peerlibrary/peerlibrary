class @Group extends AccessDocument
  # access: 0 (private, ACCESS.PRIVATE), 1 (public, ACCESS.PUBLIC)
  # readPersons: if private access, list of persons who have read permissions
  # readGroups: if private access, list of groups who have read permissions
  # createdAt: timestamp when document was created
  # updatedAt: timestamp of this version
  # slug: slug for URL
  # name: name of the group
  # members: list of people in the group
  # membersCount: number of people in the group
  # searchResult (client only): the last search query this document is a result for, if any, used only in search results
  #   _id: id of the query, an _id of the SearchResult object for the query
  #   order: order of the result in the search query, lower number means higher

  @Meta
    name: 'Group'
    fields: =>
      slug: @GeneratedField 'self', ['name']
      members: [@ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username'], true, 'inGroups']
      membersCount: @GeneratedField 'self', ['members']

  hasMaintainerAccess: (person) =>
    # User has to be logged in
    return false unless person?._id

    return true if person.isAdmin

    # Unknown access, we prevent access to the document
    # TODO: Should we log this?
    return false unless @access in [Group.ACCESS.PUBLIC, Group.ACCESS.PRIVATE]

    # TODO: Implement karma points for public documents

    return true if person._id in _.pluck @maintainerPersons, '_id'

    personGroups = _.pluck person.inGroups, '_id'
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
      'maintainerPersons._id': person._id
    ,
      'maintainerGroups._id':
        $in: _.pluck person.inGroups, '_id'
    ]

    selector.$and.push
      access:
        $in: [Group.ACCESS.PUBLIC, Group.ACCESS.PRIVATE]
      $or: accessConditions
    selector

  hasAdminAccess: (person) =>
    # User has to be logged in
    return false unless person?._id

    return true if person.isAdmin

    # Unknown access, we prevent access to the document
    # TODO: Should we log this?
    return false unless @access in [Group.ACCESS.PUBLIC, Group.ACCESS.PRIVATE]

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
        $in: [Group.ACCESS.PUBLIC, Group.ACCESS.PRIVATE]
      $or: accessConditions
    selector

  hasRemoveAccess: (person) =>
    @hasAdminAccess person

  @requireRemoveAccessSelector: (person, selector) ->
    @requireAdminAccessSelector person, selector
