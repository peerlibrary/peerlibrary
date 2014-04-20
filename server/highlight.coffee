class @Highlight extends Highlight
  @Meta
    name: 'Highlight'
    replaceParent: true

  # A set of fields which are public and can be published to the client
  @PUBLIC_FIELDS: ->
    fields: {} # All

registerForAccess Highlight

Meteor.methods
  'highlights-path': (highlightId) ->
    check highlightId, DocumentId

    highlight = Highlight.documents.findOne Highlight.requireReadAccessSelector(Meteor.person(),
      _id: highlightId
    )
    return unless highlight

    publication = Publication.documents.findOne Publication.requireCacheAccessSelector(Meteor.person(),
      _id: highlight.publication._id
    )
    return unless publication

    [publication._id, publication.slug, highlightId]

  # TODO: Use this code on the client side as well
  # By specifying various highlightIds user could check which highlights exist
  # even if otherwise they would not have access to a highlight. This does not
  # seem an issue as highlights are generally seen as public and limited only
  # to not leak private publication content in a quote.
  'create-highlight': (publicationId, highlightId, quote, target) ->
    check publicationId, DocumentId
    check highlightId, DocumentId
    check quote, NonEmptyString
    check target, [Object]

    throw new Meteor.Error 401, "User not signed in." unless Meteor.personId()

    # TODO: Check whether target conforms to schema
    # TODO: Check the target (try to apply it on the server)

    publication = Publication.documents.findOne Publication.requireCacheAccessSelector(Meteor.person(),
      _id: publicationId
    )
    throw new Meteor.Error 400, "Invalid publication." unless publication

    createdAt = moment.utc().toDate()
    highlight =
      _id: highlightId
      createdAt: createdAt
      updatedAt: createdAt
      author:
        _id: Meteor.personId()
      publication:
        _id: publicationId
      referencingAnnotations: []

    highlight = Highlight.applyDefaultAccess Meteor.personId(), highlight

    Highlight.documents.insert highlight

  'remove-highlight': (highlightId) ->
    check highlightId, DocumentId

    throw new Meteor.Error 401, "User not signed in." unless Meteor.personId()

    # TODO: Check permissions (or simply limit query to them)

    Highlight.documents.remove highlightId

Meteor.publish 'highlights-by-id', (id) ->
  check id, DocumentId

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
  check publicationId, DocumentId

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
