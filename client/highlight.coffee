class @Highlight extends Highlight
  @Meta
    name: 'Highlight'
    replaceParent: true

  # If we have the highlight and the publication available on the client,
  # we can create full path directly, otherwise we have to use highlightIdPath
  @pathFromId: (highlightId) ->
    highlight = @documents.findOne highlightId

    return Meteor.Router.highlightIdPath highlightId unless highlight

    publicationSlug = highlight.publication?.slug
    unless publicationSlug?
      publication = Publication.documents.findOne highlight.publication._id
      publicationSlug = publication?.slug

      return Meteor.Router.annotationIdPath highlightId unless publicationSlug?

    Meteor.Router.highlightPath highlight.publication._id, publicationSlug, highlightId

  path: ->
    @constructor.pathFromId @_id

  # Helper object with properties useful to refer to this document
  # Optional highlight document
  @reference: (highlightId, highlight) ->
    highlight = @documents.findOne highlightId unless highlight
    assert highlightId, highlight._id if highlight

    _id: highlightId # TODO: Remove when we will be able to access parent template context
    text: "h:#{ highlightId }"

  reference: ->
    @constructor.reference @_id, @

Handlebars.registerHelper 'highlightPathFromId', Highlight.pathFromId

Handlebars.registerHelper 'highlightReference', Highlight.reference