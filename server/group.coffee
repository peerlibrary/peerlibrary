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

registerForAccess Group

# Make sure person is valid and return person object
getValidPerson = ->
  person = Meteor.person()
  throw new Meteor.Error 401, "User not signed in." unless person
  person

# Make sure group is valid and return group object
getValidGroup = (groupId, person) ->
  throw new Error 'Group ID not set' unless groupId
  throw new Error 'Person not set' unless person
  group = Group.documents.findOne Group.requireReadAccessSelector(person,
    _id: groupId
  )
  throw new Meteor.Error 400, "Invalid group." unless group
  group

Meteor.methods
  'create-group': (name) ->
    check name, NonEmptyString
    person = getValidPerson()

    createdAt = moment.utc().toDate()
    group =
      createdAt: createdAt
      updatedAt: createdAt
      name: name
      members: [
        _id: person._id
      ]
      membershipPolicy: 'conditional'
      pendingMemers: []

    group = Group.applyDefaultAccess person._id, group

    Group.documents.insert group

  # TODO: Use this code on the client side as well
  'remove-group': (groupId) ->
    check groupId, DocumentId
    person = getValidPerson()
    group = getValidGroup groupId, person

    Group.documents.remove Group.requireRemoveAccessSelector(person,
      _id: group._id
    )

  # TODO: Use this code on the client side as well
  'add-to-group': (groupId, memberId) ->
    check groupId, DocumentId
    check memberId, DocumentId if memberId
    person = getValidPerson()
    group = getValidGroup groupId, person

    member = Person.documents.findOne
      _id: memberId
    return 0 unless member

    # We remove pending membership without checking because query checks
    Group.documents.update Group.requireAdminAccessSelector(person,
      _id: group._id
      'pendingMembers._id': member._id
    ),
      $pull:
        pendingMembers:
          _id: member._id

    # We do not check here if user is already a member of the group because query checks
    # TODO: Notify new member
    Group.documents.update Group.requireAdminAccessSelector(person,
      _id: group._id
      'members._id':
        $ne: member._id
    ),
      $addToSet:
        members:
          _id: member._id

  # TODO: Use this code on the client side as well
  'remove-from-group': (groupId, memberId) ->
    check groupId, DocumentId
    check memberId, DocumentId
    person = getValidPerson()
    group = getValidGroup groupId, person

    member = Person.documents.findOne
      _id: memberId
    return 0 unless member

    # TODO: What is return value here?

    # We do not check here if user is really a member of the group because query checks
    Group.documents.update Group.requireAdminAccessSelector(person,
      _id: group._id
      'members._id': member._id
    ),
      $pull:
        members:
          _id: member._id

    # We do not check here if user is really a pending member of the group, query checks
    Group.documents.update Group.requireAdminAccessSelector(person,
      _id: group._id
      'pendingMembers._id': member._id
    ),
      $pull:
        pendingMembers:
          _id: member._id

  # TODO: Use this code on the client side as well
  'group-set-name': (groupId, name) ->
    check groupId, DocumentId
    check name, NonEmptyString
    person = getValidPerson()
    group = getValidGroup groupId, person

    Group.documents.update Group.requireMaintainerAccessSelector(person,
      _id: group._id
    ),
      $set:
        name: name

  'group-set-membership-policy': (groupId, policy) ->
    check groupId, DocumentId
    check policy, NonEmptyString
    person = getValidPerson()
    group = getValidGroup groupId, person
    throw new Meteor.Error 400, "Invalid policy" if policy not in ['open', 'closed', 'conditional']

    Group.documents.update Group.requireMaintainerAccessSelector(person,
      _id: group._id
    ),
      $set:
        membershipPolicy: policy

  # Adds member to open group or pending member to conditional group
  'join-group': (groupId) ->
    check groupId, DocumentId
    person = getValidPerson()
    group = getValidGroup groupId, person
    throw new Meteor.Error 400, "You are not allowed to join this group." if group.membershipPolicy is 'closed'

    if group.membershipPolicy is 'open'
      newItem = members: _id: person._id
    else
      # TODO: Notify admins from observer
      newItem = pendingMembers: _id: person._id

    Group.documents.update
      _id: group._id
    ,
      $addToSet: newItem

  'cancel-membership-request': (groupId) ->
    check groupId, DocumentId
    person = getValidPerson()
    group = getValidGroup groupId, person

    Group.documents.update
      _id: group._id
      'pendingMembers._id': person._id
    ,
      $pull:
        pendingMembers:
          _id: person._id

  # Removes member from group
  'leave-group': (groupId) ->
    check groupId, DocumentId
    person = getValidPerson()
    group = getValidGroup groupId, person
    throw new Meteor.Error 400, "You are the last remaining administrator of this group." if group.adminPersons.length is 1 and group.adminPersons[0]._id is person._id

    Group.documents.update
      _id: group._id
      'members._id': person._id
    ,
      $pull:
        members:
          _id: person._id

Meteor.publish 'groups-by-id', (groupId) ->
  check groupId, DocumentId

  @related (person) ->
    Group.documents.find Group.requireReadAccessSelector(person,
      _id: groupId
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
  check limit, PositiveNumber
  check filter, OptionalOrNull String
  check sortIndex, OptionalOrNull Number
  check sortIndex, Match.Where ->
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
