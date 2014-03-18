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

Meteor.publish 'groups-by-id', (id) ->
  check id, String

  return unless id

  Group.documents.find
    _id: id
  ,
    Group.PUBLIC_FIELDS()
