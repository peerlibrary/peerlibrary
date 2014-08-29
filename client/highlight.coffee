class @Highlight extends Highlight
  @Meta
    name: 'Highlight'
    replaceParent: true

  # If we have the highlight and the publication available on the client,
  # we can create full path directly, otherwise we have to use highlightIdPath
  @pathFromId: (highlightId, options) ->
    assert _.isString highlightId

    highlight = @documents.findOne highlightId

    return Meteor.Router.highlightIdPath highlightId unless highlight

    publicationSlug = highlight.publication?.slug
    unless publicationSlug?
      publication = Publication.documents.findOne highlight.publication._id
      publicationSlug = publication?.slug

      return Meteor.Router.annotationIdPath highlightId unless publicationSlug?

    Meteor.Router.highlightPath highlight.publication._id, publicationSlug, highlightId

  path: =>
    @constructor.pathFromId @_id

  route: =>
    route: 'highlight'
    params:
      publicationId: @publication?._id
      publicationSlug: @publication?.slug
      highlightId: @_id

  # Helper object with properties useful to refer to this document. Optional group document.
  @reference: (highlightId, highlight, options) ->
    assert _.isString highlightId
    # To allow calling template helper with only one argument (highlight will be options then)
    highlight = null unless highlight instanceof @

    highlight = @documents.findOne highlightId unless highlight
    assert highlightId, highlight._id if highlight

    _id: highlightId # TODO: Remove when we will be able to access parent template context
    text: "h:#{ highlightId }"

  reference: =>
    @constructor.reference @_id, @

Handlebars.registerHelper 'highlightPathFromId', _.bind Highlight.pathFromId, Highlight

Handlebars.registerHelper 'highlightReference', _.bind Highlight.reference, Highlight
