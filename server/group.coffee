SLUG_MAX_LENGTH = 80

emailRequestToJoinDeniedSubject = (person, group) ->
  "Your request to join group #{group.name} has been declined."
emailRequestToJoinDeniedText = (person, group) ->
  "Hi #{person.displayName}, administrators of group \"#{group.name}\" have declined your request to join."
emailrequestToJoinApprovedSubject = (person, group) ->
  ""
emailrequestToJoinApprovedtext = (person, group) ->
  ""
emailRequestToLeaveDeniedSubject = (person, group) ->
  ""
emailRequestToLeaveDeniedText = (person, group) ->
  ""
emailRequestToLeaveApprovedSubject = (person, group) ->
  ""
emailRequestToLeaveApprovedText = (person, group) ->
  ""

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
      joinPolicy: Group.POLICY.APPROVAL
      leavePolicy: Group.POLICY.OPEN
      joinRequests: []
      leaveRequests: []

    group = Group.applyDefaultAccess person._id, group

    Group.documents.insert group

  # TODO: Use this code on the client side as well
  'remove-group': methodWrap (groupId) ->
    validateArgument 'groupId', groupId, DocumentId
    person = getValidPerson()
    group = getValidGroup groupId, person

    Group.documents.remove Group.requireRemoveAccessSelector(person,
      _id: group._id
    )

  # TODO: Use this code on the client side as well
  'add-to-group': methodWrap (groupId, memberId) ->
    validateArgument 'groupId', groupId, DocumentId
    validateArgument 'groupId', memberId, DocumentId
    person = getValidPerson()
    group = getValidGroup groupId, person

    member = Person.documents.findOne
      _id: memberId
    return 0 unless member

    # We remove request to join without checking because query checks
    requestApproved = Group.documents.update Group.requireAdminAccessSelector(person,
      _id: group._id
      'joinRequests._id': member._id
    ),
      $pull:
        joinRequests:
          _id: member._id

    # We do not check here if user is already a member of the group because query checks
    Group.documents.update Group.requireAdminAccessSelector(person,
      _id: group._id
      'members._id':
        $ne: member._id
    ),
      $addToSet:
        members:
          _id: member._id

    # If request was approved send e-mail to new member.
    if requestApproved
      @unblock()
      try
        Email.send
          from: Accounts.emailTemplates.from
          to: person.user.emails[0].address
          subject: emailRequestToJoinApprovedSubject person, group
          text: emailRequestToJoinApprovedText person, group
      catch error
        # TODO: What to do?

  # TODO: Use this code on the client side as well
  'deny-request-to-join-group': methodWrap (groupId, memberId) ->
    validateArgument 'groupId', groupId, DocumentId
    validateArgument 'groupId', memberId, DocumentId
    person = getValidPerson()
    group = getValidGroup groupId, person

    # We do not check here if member with given id exists because query checks
    requestDenied = Group.documents.update Group.requireAdminAccessSelector(person,
      _id: group._id
      'joinRequests._id': memberId
    ),
      $pull:
        joinRequests:
          _id: memberId

    # If request is denied, send e-mail to member.
    if requestDenied
      @unblock()
      try
        Email.send
          from: Accounts.emailTemplates.from
          to: person.user.emails[0].address
          subject: emailRequestToJoinDeniedSubject person, group
          text: emailRequestToJoinDeniedText person, group
      catch error
        # TODO: What to do?

    requestDenied

  # TODO: Use this code on the client side as well
  'remove-from-group': methodWrap (groupId, memberId) ->
    validateArgument 'groupId', groupId, DocumentId
    validateArgument 'memberId', memberId, DocumentId
    person = getValidPerson()
    group = getValidGroup groupId, person
    throw new Meteor.Error 400, "Member is last remaining administrator of this group." if group.adminPersons.length is 1 and group.adminPersons[0]._id is memberId

    # We remove request to leave without checking because query checks
    requestApproved = Group.documents.update Group.requireAdminAccessSelector(person,
      _id: group._id
      'leaveRequests._id': memberId
    ),
      $pull:
        leaveRequests:
          _id: memberId

    # We do not check here if user is really a member of the group because query checks
    Group.documents.update Group.requireAdminAccessSelector(person,
      _id: group._id
      'members._id': memberId
    ),
      $pull:
        members:
          _id: memberId

    # If request was approved send e-mail to member
    if requestApproved
      @unblock()
      try
        Email.send
          from: Accounts.emailTemplates.from
          to: person.user.emails[0].address
          subject: emailRequestToLeaveApprovedSubject person, group
          text: emailRequestToLeaveApprovedText person, group
      catch error
        # TODO: What to do?

  'deny-request-to-leave-group': methodWrap (groupId, memberId) ->
    validateArgument 'groupId', groupId, DocumentId
    validateArgument 'membrerId', memberId, DocumentId
    person = getValidPerson()
    group = getValidGroup groupId, person

    # We do not check here if member with given id exists because query checks
    requestDenied = Group.documents.update Group.requireAdminAccessSelector(person,
      _id: group._id
      'leaveRequests._id': memberId
    ),
      $pull:
        leaveRequests:
          _id: memberId

    # if requestDenied send e-mail to member
    if requestDenied
      @unblock()
      try
        Email.send
          from: Accounts.emailTemplates.from
          to: person.user.emails[0].address
          subject: emailRequestToLeaveDeniedSubject person, group
          text: emailRequestToLeaveDeniedText person, group
      catch error
        # TODO: What to do?

    requestDenied

  # TODO: Use this code on the client side as well
  'group-set-name': methodWrap (groupId, name) ->
    validateArgument 'groupId', groupId, DocumentId
    validateArgument 'name', name, NonEmptyString
    person = getValidPerson()
    group = getValidGroup groupId, person

    Group.documents.update Group.requireMaintainerAccessSelector(person,
      _id: group._id
    ),
      $set:
        name: name

  'group-set-join-policy': methodWrap (groupId, policy) ->
    validateArgument 'groupId', groupId, DocumentId
    validateArgument 'policy', policy, MatchAccess Group.POLICY
    person = getValidPerson()
    group = getValidGroup groupId, person

    modifier = $set:
      joinPolicy: policy
    # If new policy is CLOSED, deny all requests.
    if policy is Group.POLICY.CLOSED
      modifier['$set']['joinRequests'] = []
    # If new policy is OPEN, accept all requests.
    else if policy is Group.POLICY.OPEN
      modifier['$set']['joinRequests']= []
      modifier['$addToSet'] = members:
        $each: group.joinRequests

    Group.documents.update Group.requireAdminAccessSelector(person,
      _id: group._id
    ),
      modifier

  'group-set-leave-policy': methodWrap (groupId, policy) ->
    validateArgument 'groupId', groupId, DocumentId
    validateArgument 'policy', policy, MatchAccess Group.POLICY
    person = getValidPerson()
    group = getValidGroup groupId, person

    modifier = $set:
      leavePolicy: policy
    # If new policy is CLOSED, deny all requests.
    if policy is Group.POLICY.CLOSED
      modifier['$set']['leaveRequests'] = []
    # If new policy is OPEN, accept all requests.
    else if policy is Group.POLICY.OPEN
      modifier['$set']['leaveRequests'] = []
      modifier['$pullAll'] = members: group.leaveRequests

    Group.documents.update Group.requireAdminAccessSelector(person,
      _id: group._id
    ),
      modifier

  'request-to-join-group': methodWrap (groupId) ->
    validateArgument 'groupId', groupId, DocumentId
    person = getValidPerson()
    group = getValidGroup groupId, person
    throw new Meteor.Error 400, "You are not allowed to join this group." if group.joinPolicy is Group.POLICY.CLOSED

    if group.joinPolicy is Group.POLICY.OPEN
      Group.documents.update
        _id: group._id
      ,
        $addToSet:
          members:
            _id: person._id
    else
      requestAdded = Group.documents.update
        _id: group._id
        'joinRequests._id':
          $ne: person._id
      ,
        $addToSet:
          joinRequests:
            _id: person._id
      # TODO: If requestAdded send e-mail to admins
      requestAdded

  'cancel-request-to-join-group': methodWrap (groupId) ->
    validateArgument 'groupId', groupId, DocumentId
    person = getValidPerson()
    group = getValidGroup groupId, person

    Group.documents.update
      _id: group._id
      'joinRequests._id': person._id
    ,
      $pull:
        joinRequests:
          _id: person._id

  'request-to-leave-group': methodWrap (groupId) ->
    validateArgument 'groupId', groupId, DocumentId
    person = getValidPerson()
    group = getValidGroup groupId, person
    throw new Meteor.Error 400, "You are not allowed to leave this group." if group.leavePolicy is Group.POLICY.CLOSED
    throw new Meteor.Error 400, "You are the last remaining administrator of this group." if group.adminPersons.length is 1 and group.adminPersons[0]._id is person._id

    if group.leavePolicy is Group.POLICY.OPEN
      Group.documents.update
        _id: group._id
      ,
        $pull:
          members:
            _id: person._id
    else
      requestAdded = Group.documents.update
        _id: group._id
        'leaveRequests._id':
          $ne: person._id
      ,
        $addToSet:
          leaveRequests:
            _id: person._id
      # TODO: If requestAdded send e-mail to admins
      requestAdded

  'cancel-request-to-leave-group': methodWrap (groupId) ->
    validateArgument 'groupId', groupId, DocumentId
    person = getValidPerson()
    group = getValidGroup groupId, person

    Group.documents.update
      _id: group._id
      'leaveRequests._id': person._id
    ,
      $pull:
        leaveRequests:
          _id: person._id

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

Meteor.publish 'my-join-requests', (groupId) ->
  validateArgument 'groupId', groupId, DocumentId

  @related (person) ->
    return unless person?._id

    Group.documents.find Group.requireReadAccessSelector(person,
      _id: groupId,
      'joinRequests._id': person._id
    ),
      fields: _.extend Group.PUBLISH_FIELDS().fields,
        'joinRequests.$': 1
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: Publication.readAccessPersonFields()

Meteor.publish 'my-leave-requests', (groupId) ->
  validateArgument 'groupId', groupId, DocumentId

  @related (person) ->
    return unless person?._id

    Group.documents.find Group.requireReadAccessSelector(person,
      _id: groupId,
      'leaveRequests._id': person._id
    ),
      fields: _.extend Group.PUBLISH_FIELDS().fields,
        'leaveRequests.$': 1
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: Publication.readAccessPersonFields()

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
