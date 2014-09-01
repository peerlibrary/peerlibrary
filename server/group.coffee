SLUG_MAX_LENGTH = 80

class @Group extends Group
  @Meta
    name: 'Group'
    replaceParent: true
    fields: (fields) =>
      fields.slug.generator = (fields) ->
        if fields.name
          [fields._id, URLify2 fields.name, SLUG_MAX_LENGTH]
        else
          [fields._id, '']

      fields.membersCount.generator = (fields) ->
        [fields._id, fields.members?.length or 0]

      fields

  # A set of fields which are public and can be published to the client
  @PUBLISH_FIELDS: ->
    fields: {} # All

  # A subset of public fields used for catalog results
  @PUBLISH_CATALOG_FIELDS: ->
    fields:
      slug: 1
      name: 1
      membersCount: 1
      access: 1

registerForAccess Group

Meteor.methods
  'create-group': methodWrap (name) ->
    validateArgument 'name', name, NonEmptyString

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    createdAt = moment.utc().toDate()
    group =
      createdAt: createdAt
      updatedAt: createdAt
      name: name
      members: [
        _id: person._id
      ]

    group = Group.applyDefaultAccess person._id, group

    Group.documents.insert group

  # TODO: Use this code on the client side as well
  'remove-group': methodWrap (groupId) ->
    validateArgument 'groupId', groupId, DocumentId

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    group = Group.documents.findOne Group.requireReadAccessSelector(person,
      _id: groupId
    )
    throw new Meteor.Error 400, "Invalid group." unless group

    Group.documents.remove Group.requireRemoveAccessSelector(person,
      _id: group._id
    )

  # TODO: Use this code on the client side as well
  'add-to-group': methodWrap (groupId, memberId) ->
    validateArgument 'groupId', groupId, DocumentId
    validateArgument 'groupId', memberId, DocumentId

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    group = Group.documents.findOne Group.requireReadAccessSelector(person,
      _id: groupId
    )
    throw new Meteor.Error 400, "Invalid group." unless group

    member = Person.documents.findOne
      _id: memberId
    return 0 unless member

    # We do not check here if user is already a member of the group because query checks

    Group.documents.update Group.requireAdminAccessSelector(person,
      _id: group._id
      'members._id':
        $ne: member._id
    ),
      $addToSet:
        members:
          _id: member._id

  # TODO: Use this code on the client side as well
  'remove-from-group': methodWrap (groupId, memberId) ->
    validateArgument 'groupId', groupId, DocumentId
    validateArgument 'groupId', memberId, DocumentId

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    group = Group.documents.findOne Group.requireReadAccessSelector(person,
      _id: groupId
    )
    throw new Meteor.Error 400, "Invalid group." unless group

    member = Person.documents.findOne
      _id: memberId
    return 0 unless member

    # We do not check here if user is really a member of the group because query checks

    Group.documents.update Group.requireAdminAccessSelector(person,
      _id: group._id
      'members._id': member._id
    ),
      $pull:
        members:
          _id: member._id

  # TODO: Use this code on the client side as well
  'group-set-name': methodWrap (groupId, name) ->
    validateArgument 'groupId', groupId, DocumentId
    validateArgument 'name', name, NonEmptyString

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    group = Group.documents.findOne Group.requireReadAccessSelector(person,
      _id: groupId
    )
    throw new Meteor.Error 400, "Invalid group." unless group

    Group.documents.update Group.requireMaintainerAccessSelector(person,
      _id: group._id
    ),
      $set:
        name: name

Meteor.publish 'groups-by-ids', (groupIds) ->
  validateArgument 'groupIds', groupIds, Match.OneOf DocumentId, [DocumentId]

  groupIds = [groupIds] unless _.isArray groupIds

  @related (person) ->
    Group.documents.find Group.requireReadAccessSelector(person,
      _id:
        $in: groupIds
    ),
      Group.PUBLISH_FIELDS()
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: _.extend Group.readAccessPersonFields()

Meteor.publish 'my-groups', ->
  @related (person) ->
    return unless person?._id

    Group.documents.find Group.requireReadAccessSelector(person,
      'members._id': person._id
    ),
      Group.PUBLISH_CATALOG_FIELDS()
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: _.extend Group.readAccessPersonFields()

Meteor.publish 'groups', (limit, filter, sortIndex) ->
  validateArgument 'limit', limit, PositiveNumber
  validateArgument 'filter', filter, OptionalOrNull String
  validateArgument 'sortIndex', sortIndex, OptionalOrNull Number
  validateArgument 'sortIndex', sortIndex, Match.Where (sortIndex) ->
    not _.isNumber(sortIndex) or 0 <= sortIndex < Group.PUBLISH_CATALOG_SORT.length

  findQuery = {}
  findQuery = createQueryCriteria(filter, 'name') if filter

  sort = if _.isNumber sortIndex then Group.PUBLISH_CATALOG_SORT[sortIndex].sort else null

  @related (person) ->
    restrictedFindQuery = Group.requireReadAccessSelector person, findQuery

    searchPublish @, 'groups', [filter, sortIndex],
      cursor: Group.documents.find restrictedFindQuery,
        limit: limit
        fields: Group.PUBLISH_CATALOG_FIELDS().fields
        sort: sort
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: _.extend Group.readAccessPersonFields()

ensureCatalogSortIndexes Group
