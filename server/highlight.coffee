class @Highlight extends @Highlight
  # A set of fields which are public and can be published to the client
  @PUBLIC_FIELDS: ->
    fields: {} # All

Highlights.allow
  insert: (userId, doc) ->
    # TODO: Check whether inserted document conforms to schema
    # TODO: Check the target (try to apply it on the server)
    # TODO: Check that author really has access to the publication

    return false unless userId

    personId = Meteor.personId userId

    personId and doc.author._id is personId

# Misuse insert validation to add additional fields on the server before insertion
Highlights.deny
  # We have to disable transformation so that we have
  # access to the document object which will be inserted
  transform: null

  insert: (userId, doc) ->
    doc.created = moment.utc().toDate()

    # We return false as we are not
    # checking anything, just adding fields
    false

Meteor.publish 'highlights-by-publication', (publicationId) ->
  check publicationId, String

  return unless publicationId

  Highlights.find
    'publication._id': publicationId
  ,
    Highlight.PUBLIC_FIELDS()
