class @Annotation extends @Annotation
  # A set of fields which are public and can be published to the client
  @PUBLIC_FIELDS: ->
    fields: {} # All

Annotations.allow
  insert: (userId, doc) ->
    # TODO: Check whether inserted document conforms to schema
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
Annotations.deny
  # We have to disable transformation so that we have
  # access to the document object which will be inserted
  transform: null

  insert: (userId, doc) ->
    doc.created = moment.utc().toDate()
    doc.updated = doc.created

    # We return false as we are not
    # checking anything, just adding fields
    false

  update: (userId, doc) ->
    doc.updated = moment.utc().toDate()
    
    # We return false as we are not
    # checking anything, just updating fields
    false

Meteor.publish 'annotations-by-publication', (publicationId) ->
  check publicationId, String

  return unless publicationId

  Annotations.find
    'publication._id': publicationId
  ,
    Annotation.PUBLIC_FIELDS()
