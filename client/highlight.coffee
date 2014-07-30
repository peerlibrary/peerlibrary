class @Highlight extends Highlight
  @Meta
    name: 'Highlight'
    replaceParent: true

  @pathFromId: (highlightId) ->
    # If we have the highlight and the publication available on the client,
    # we can create full path directly, otherwise we have to use highlightIdPath
    highlight = Highlight.documents.findOne highlightId

    return Meteor.Router.highlightIdPath highlightId unless highlight

    publication = Publication.documents.findOne highlight.publication._id

    return Meteor.Router.highlightIdPath highlightId unless publication

    Meteor.Router.highlightPath publication._id, publication.slug, highlightId

  path: ->
    Highlight.pathFromId @_id

  # Helper object with properties useful to refer to this document
  # Optional highlight document
  @reference: (highlightId, highlight) ->
    highlight = Highlight.documents.findOne highlightId unless highlight
    assert highlightId, highlight._id if highlight

    _id: highlightId # TODO: Remove when we will be able to access parent template context
    text: "h:#{ highlightId }"

  reference: ->
    Highlight.reference @_id, @


Handlebars.registerHelper 'highlightPathFromId', Highlight.pathFromId

Handlebars.registerHelper 'highlightReference', Highlight.reference