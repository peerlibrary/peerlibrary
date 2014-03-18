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

  # A set of fields which are public and can be published to the client
  @PUBLIC_FIELDS: ->
    fields: {} # All

Group.Meta.collection.allow
  insert: (userId, doc) ->
    # TODO: Check whether inserted document conforms to schema

    return false unless userId

    personId = Meteor.personId userId

    # Only allow insertion if current user is among members
    personId and personId in _.pluck(doc.members, '_id')

  update: (userId, doc) ->
    return false unless userId

    personId = Meteor.personId userId

    # Only allow update if current user is among members
    personId and personId in _.pluck(doc.members, '_id')

  remove: (userId, doc) ->
    return false unless userId

    personId = Meteor.personId userId

    # Only allow removal if current user is among members
    personId and personId in _.pluck(doc.members, '_id')

# Misuse insert validation to add additional fields on the server before insertion
Group.Meta.collection.deny
  # We have to disable transformation so that we have
  # access to the document object which will be inserted
  transform: null

  insert: (userId, doc) ->
    doc.createdAt = moment.utc().toDate()
    doc.updatedAt = doc.createdAt

    # We return false as we are not
    # checking anything, just adding fields
    false

  update: (userId, doc) ->
    doc.updatedAt = moment.utc().toDate()

    # We return false as we are not
    # checking anything, just updating fields
    false

Meteor.methods
  # TODO: Move this code to the client side so that we do not have to duplicate document checks from Group.Meta.collection.allow and modifications from Group.Meta.collection.deny, see https://github.com/meteor/meteor/issues/1921
  'add-to-group': (groupId, memberId) ->
    check groupId, String
    check memberId, String

    throw new Meteor.Error 401, "User not signed in." unless Meteor.personId()

    # We do not check here if group exists or if user is a member of it because we have query below with these conditions

    Group.documents.update
      _id: groupId
      $and: [
        'members._id': Meteor.personId()
      ,
        'members._id':
          $ne: memberId
      ]
    ,
      $set:
        updatedAt: moment.utc().toDate()
      $addToSet:
        members:
          _id: memberId

Meteor.publish 'groups-by-id', (id) ->
  check id, String

  return unless id

  Group.documents.find
    _id: id
  ,
    Group.PUBLIC_FIELDS()
