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
  @PUBLIC_FIELDS: ->
    fields: {} # All

  @PUBLIC_LISTING_FIELDS: ->
    fields:
      slug: 1
      name: 1
      membersCount: 1

# TODO: Use this code on the client side as well
Meteor.methods
  'create-group': (name) ->
    check name, String

    throw new Meteor.Error 401, "User not signed in." unless Meteor.personId()

    throw new Meteor.Error 400, "Name required." unless name

    createdAt = moment.utc().toDate()
    Group.documents.insert
      createdAt: createdAt
      updatedAt: createdAt
      name: name
      members: [
        _id: Meteor.personId()
      ]

  'add-to-group': (groupId, memberId) ->
    check groupId, String
    check memberId, String

    throw new Meteor.Error 401, "User not signed in." unless Meteor.personId()

    # We do not check here if group exists or if user is a member of it because we have query below with these conditions

    # TODO: Check that memberId has an user associated with it? Or should we allow adding persons even if they are not users? So that you can create a group of lab mates, without having for all of them to be registered?

    # TODO: Should be allowed also if user is admin

    member = Person.documents.findOne
      _id: memberId

    return unless member

    Group.documents.update
      _id: groupId
      $and: [
        'members._id': Meteor.personId()
      ,
        'members._id':
          $ne: member._id
      ]
    ,
      $set:
        updatedAt: moment.utc().toDate()
      $addToSet:
        members:
          _id: member._id

  'remove-from-group': (groupId, memberId) ->
    check groupId, String
    check memberId, String

    throw new Meteor.Error 401, "User not signed in." unless Meteor.personId()

    # We do not check here if group exists or if user is a member of it because we have query below with these conditions

    # TODO: Should be allowed also if user is admin

    member = Person.documents.findOne
      _id: memberId

    return unless member

    Group.documents.update
      _id: groupId
      $and: [
        'members._id': Meteor.personId()
      ,
        'members._id': member._id
      ]
    ,
      $set:
        updatedAt: moment.utc().toDate()
      $pull:
        members:
          _id: member._id

Meteor.publish 'groups-by-id', (id) ->
  check id, String

  return unless id

  Group.documents.find
    _id: id
  ,
    Group.PUBLIC_FIELDS()

Meteor.publish 'my-groups', ->
  Group.documents.find
    'members._id': @personId
  ,
    Group.PUBLIC_LISTING_FIELDS()

Meteor.publish 'groups', ->
  # TODO: Return a subset of groups with pagination and provide extra methods for server side group searching. See https://github.com/peerlibrary/peerlibrary/issues/363
  Group.documents.find {}, Group.PUBLIC_LISTING_FIELDS()
