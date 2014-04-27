# If we have the comment and the publication available on the client,
# we can create full path directly, otherwise we have to use commentIdPath
Handlebars.registerHelper 'commentPathFromId', (commentId, options) ->
  comment = Comment.documents.findOne commentId

  return Meteor.Router.commentIdPath commentId unless comment

  publication = Publication.documents.findOne comment.publication._id

  return Meteor.Router.commentIdPath commentId unless publication

  Meteor.Router.commentPath publication._id, publication.slug, commentId
