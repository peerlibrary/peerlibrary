# If we have the highlight and the publication available on the client,
# we can create full path directly, otherwise we have to use highlightIdPath
Handlebars.registerHelper 'highlightPathFromId', (highlightId, options) ->
  highlight = Highlights.findOne highlightId

  return Meteor.Router.highlightIdPath highlightId unless highlight

  publication = Publications.findOne highlight.publication._id

  return Meteor.Router.highlightIdPath highlightId unless publication

  Meteor.Router.highlightPath publication._id, publication.slug, highlightId
