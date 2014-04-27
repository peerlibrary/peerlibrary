# If we have the highlight and the publication available on the client,
# we can create full path directly, otherwise we have to use highlightIdPath
Handlebars.registerHelper 'highlightPathFromId', (highlightId, options) ->
  highlight = Highlight.documents.findOne highlightId

  return Meteor.Router.highlightIdPath highlightId unless highlight

  publication = Publication.documents.findOne highlight.publication._id

  return Meteor.Router.highlightIdPath highlightId unless publication

  Meteor.Router.highlightPath publication._id, publication.slug, highlightId

# Optional highlight document
Handlebars.registerHelper 'highlightReference', (highlightId, highlight, options) ->
  highlight = Highlight.documents.findOne highlightId unless highlight

  text: "h:#{ highlightId }"
