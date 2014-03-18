class @Highlight extends Highlight
  @Meta
    name: 'Highlight'
    replaceParent: true

  # A set of fields which are public and can be published to the client
  @PUBLIC_FIELDS: ->
    fields: {} # All

Highlight.Meta.collection.allow
  insert: (userId, doc) ->
    # TODO: Check whether inserted document conforms to schema
    # TODO: Check the target (try to apply it on the server)
    # TODO: Check that author really has access to the publication

    return false unless userId

    personId = Meteor.personId userId

    # Only allow insertion if declared author is current user
    personId and doc.author._id is personId

  update: (userId, doc) ->
    return false unless userId

    personId = Meteor.personId userId

    # Only allow update if declared author is current user
    personId and doc.author._id is personId

  remove: (userId, doc) ->
    return false unless userId

    personId = Meteor.personId userId

    # Only allow removal if author is current user
    personId and doc.author._id is personId

# Misuse insert validation to add additional fields on the server before insertion
Highlight.Meta.collection.deny
  # We have to disable transformation so that we have
  # access to the document object which will be inserted
  transform: null

  insert: (userId, doc) ->
    doc.created = moment.utc().toDate()
    doc.updated = doc.created
    doc.annotations = [] if not doc.annotations

    # We return false as we are not
    # checking anything, just adding fields
    false

  update: (userId, doc) ->
    doc.updated = moment.utc().toDate()

    # We return false as we are not
    # checking anything, just updating fields
    false

Meteor.publish 'highlights-by-id', (id) ->
  check id, String

  return unless id

  Highlight.documents.find
    _id: id
  ,
    Highlight.PUBLIC_FIELDS()

Meteor.publish 'highlights-by-publication', (publicationId) ->
  check publicationId, String

  return unless publicationId

  Highlight.documents.find
    'publication._id': publicationId
  ,
    Highlight.PUBLIC_FIELDS()
