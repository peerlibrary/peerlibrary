class @Comment extends Comment
  @Meta
    name: 'Comment'
    replaceParent: true

  @pathFromId: (commentId) ->
    # If we have the comment and the publication available on the client,
    # we can create full path directly, otherwise we have to use commentIdPath
    comment = Comment.documents.findOne commentId

    return Meteor.Router.commentIdPath commentId unless comment

    publication = Publication.documents.findOne comment.publication._id

    return Meteor.Router.commentIdPath commentId unless publication

    Meteor.Router.commentPath publication._id, publication.slug, commentId

  path: ->
    Comment.pathFromId @_id

  # Helper object with properties useful to refer to this document
  # Optional comment document
  @reference: (commentId, comment) ->
    comment = Comment.documents.findOne commentId unless comment
    assert commentId, comment._id if comment

    _id: commentId # TODO: Remove when we will be able to access parent template context
    text: "m:#{ commentId }"

  reference: ->
    Comment.reference @_id, @

Handlebars.registerHelper 'commentPathFromId', Comment.pathFromId

Handlebars.registerHelper 'commentReference', Comment.reference
