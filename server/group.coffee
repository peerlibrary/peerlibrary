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
        [fields._id, fields.members.length]

  # A set of fields which are public and can be published to the client
  @PUBLISH_FIELDS: ->
    fields: {} # All

  # A subset of public fields used when listing documents
  @PUBLISH_LISTING_FIELDS: ->
    fields:
      slug: 1
      name: 1
      membersCount: 1

registerForAccess Group

Meteor.methods
  'create-group': (name) ->
    check name, NonEmptyString

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
  'add-to-group': (groupId, memberId) ->
    check groupId, DocumentId
    check memberId, DocumentId

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
      _id: groupId
      'members._id':
        $ne: memberId
    ),
      $set:
        updatedAt: moment.utc().toDate()
      $addToSet:
        members:
          _id: memberId

  # TODO: Use this code on the client side as well
  'remove-from-group': (groupId, memberId) ->
    check groupId, DocumentId
    check memberId, DocumentId

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
      _id: groupId
      'members._id': memberId
    ),
      $set:
        updatedAt: moment.utc().toDate()
      $pull:
        members:
          _id: memberId

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
    Group.documents.find Group.requireReadAccessSelector(person,
      'members._id': person._id
    ),
      Group.PUBLISH_LISTING_FIELDS()
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: _.extend Group.readAccessPersonFields()

Meteor.publish 'groups', ->
  # TODO: Return a subset of groups with pagination and provide extra methods for server side group searching. See https://github.com/peerlibrary/peerlibrary/issues/363
  @related (person) ->
    Group.documents.find Group.requireReadAccessSelector(person,
      {}
    ),
      Group.PUBLISH_LISTING_FIELDS()
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: _.extend Group.readAccessPersonFields()
