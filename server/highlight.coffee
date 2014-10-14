class @Highlight extends Highlight
  @Meta
    name: 'Highlight'
    replaceParent: true

  # A set of fields which are public and can be published to the client
  @PUBLISH_FIELDS: ->
    fields: {} # All

  # A subset of public fields used for catalog results
  @PUBLISH_CATALOG_FIELDS: ->
    fields:
      author: 1
      publication: 1
      quote: 1

Meteor.methods
  'highlights-path': methodWrap (highlightId) ->
    validateArgument 'highlightId', highlightId, DocumentId

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
  'create-highlight': methodWrap (publicationId, highlightId, quote, target) ->
    validateArgument 'publicationId', publicationId, DocumentId
    validateArgument 'highlightId', highlightId, DocumentId
    validateArgument 'quote', quote, NonEmptyString
    validateArgument 'target', target, [Object]

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
  'remove-highlight': methodWrap (highlightId) ->
    validateArgument 'highlightId', highlightId, DocumentId

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

new PublishEndpoint 'highlights-by-publication', (publicationId) ->
  validateArgument 'publicationId', publicationId, DocumentId

  @related (person, publication) ->
    return unless publication?.hasCacheAccess person

    # We store related fields so that they are available in middlewares.
    @set 'person', person

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

new PublishEndpoint 'highlights', (limit, filter, sortIndex) ->
  validateArgument 'limit', limit, PositiveNumber
  validateArgument 'filter', filter, OptionalOrNull String
  validateArgument 'sortIndex', sortIndex, OptionalOrNull Number
  validateArgument 'sortIndex', sortIndex, Match.Where (sortIndex) ->
    not _.isNumber(sortIndex) or 0 <= sortIndex < Highlight.PUBLISH_CATALOG_SORT.length

  findQuery = {}
  findQuery = createQueryCriteria(filter, 'quote') if filter

  sort = if _.isNumber sortIndex then Highlight.PUBLISH_CATALOG_SORT[sortIndex].sort else null

  searchPublish @, 'highlights', [filter, sortIndex],
    cursor: Highlight.documents.find findQuery,
      limit: limit
      fields: Highlight.PUBLISH_CATALOG_FIELDS().fields
      sort: sort

ensureCatalogSortIndexes Highlight
