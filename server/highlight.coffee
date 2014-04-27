class @Highlight extends Highlight
  @Meta
    name: 'Highlight'
    replaceParent: true

  # A set of fields which are public and can be published to the client
  @PUBLISH_FIELDS: ->
    fields: {} # All

Meteor.methods
  'highlights-path': (highlightId) ->
    check highlightId, DocumentId

    person = Meteor.person()

    # No need for requireReadAccessSelector because highlights are public
    highlight = Highlight.documents.findOne
      _id: highlightId
    return unless highlight

    publication = Publication.documents.findOne Publication.requireCacheAccessSelector(person,
      _id: highlight.publication._id
    )
    return unless publication

    [publication._id, publication.slug, highlight._id]

  # By specifying various highlightIds user could check which highlights exist
  # even if otherwise they would not have access to a highlight. This does not
  # seem an issue as highlights are generally seen as public and limited only
  # to not leak private publication content in a quote.
  'create-highlight': (publicationId, highlightId, quote, target) ->
    check publicationId, DocumentId
    check highlightId, DocumentId
    check quote, NonEmptyString
    check target, [Object]

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    # TODO: Check whether target conforms to schema
    # TODO: Check the target (try to apply it on the server)

    publication = Publication.documents.findOne Publication.requireCacheAccessSelector(person,
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
      quote: quote
      target: target

    highlight = Highlight.applyDefaultAccess person._id, highlight

    Highlight.documents.insert highlight

  # TODO: Use this code on the client side as well
  'remove-highlight': (highlightId) ->
    check highlightId, DocumentId

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    highlight = Highlight.documents.findOne
      _id: highlightId
    # No need for hasReadAccess because highlights are public
    throw new Meteor.Error 400, "Invalid highlight." unless highlight

    publication = Publication.documents.findOne Publication.requireCacheAccessSelector(person,
      _id: highlight.publication._id
    )
    throw new Meteor.Error 400, "Invalid highlight." unless publication

    Highlight.documents.remove Highlight.requireMaintainerAccessSelector(person,
      _id: highlight._id
    )

Meteor.publish 'highlights-by-publication', (publicationId) ->
  check publicationId, DocumentId

  @related (person, publication) ->
    return unless publication?.hasCacheAccess person

    # No need for requireReadAccessSelector because highlights are public
    Highlight.documents.find
      'publication._id': publication._id
    ,
      Highlight.PUBLISH_FIELDS()
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: Publication.readAccessPersonFields()
  ,
    Publication.documents.find
      _id: publicationId
    ,
      fields: Publication.readAccessSelfFields()
