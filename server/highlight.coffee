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
    # TODO: Check that author really has access to the highlight (and publication)

    return false unless userId

    personId = Meteor.personId userId

    # Only allow insertion if declared author is current user
    personId and doc.author._id is personId

  update: (userId, doc, fieldNames, modifier) ->
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
    doc.createdAt = moment.utc().toDate()
    doc.updatedAt = doc.createdAt
    doc.annotations = [] if not doc.annotations

    doc = Highlight.applyDefaultAccess Meteor.personId(userId), doc

    # We return false as we are not
    # checking anything, just adding fields
    false

  update: (userId, doc) ->
    doc.updatedAt = moment.utc().toDate()

    # We return false as we are not
    # checking anything, just updating fields
    false

registerForAccess Highlight

Meteor.methods
  'highlights-path': (highlightId) ->
    check highlightId, String

    highlight = Highlight.documents.findOne Highlight.requireReadAccessSelector(Meteor.person(),
      _id: highlightId
    )
    return unless highlight

    publication = Publication.documents.findOne Publication.requireCacheAccessSelector(Meteor.person(),
      _id: highlight.publication._id
    )
    return unless publication

    [publication._id, publication.slug, highlightId]

Meteor.publish 'highlights-by-id', (id) ->
  check id, String

  return unless id

  @related (person, publication) ->
    return unless publication?.hasCacheAccess person

    Highlight.documents.find Highlight.requireReadAccessSelector(person,
      _id: id
    ), Highlight.PUBLIC_FIELDS()
  ,
    Person.documents.find
      _id: @personId
    ,
      fields:
        # _id field is implicitly added
        isAdmin: 1
        inGroups: 1
        library: 1 # Needed by hasReadAccess
  ,
    Publication.documents.find
      'annotations._id': id
    ,
      fields:
        # _id field is implicitly added
        cached: 1
        processed: 1
        access: 1
        readPersons: 1
        readGroups: 1

Meteor.publish 'highlights-by-publication', (publicationId) ->
  check publicationId, String

  return unless publicationId

  @related (person, publication) ->
    return unless publication?.hasCacheAccess person

    Highlight.documents.find Highlight.requireReadAccessSelector(person,
      'publication._id': publicationId
    ), Highlight.PUBLIC_FIELDS()
  ,
    Person.documents.find
      _id: @personId
    ,
      fields:
        # _id field is implicitly added
        isAdmin: 1
        inGroups: 1
        library: 1 # Needed by hasReadAccess
  ,
    Publication.documents.find
      _id: publicationId
    ,
      fields:
        # _id field is implicitly added
        cached: 1
        processed: 1
        access: 1
        readPersons: 1
        readGroups: 1
