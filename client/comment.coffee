class @Comment extends Comment
  @Meta
    name: 'Comment'
    replaceParent: true

  # If we have the comment and the publication available on the client,
  # we can create full path directly, otherwise we have to use commentIdPath
  @pathFromId: (commentId) ->
    assert _.isString commentId

    comment = @documents.findOne commentId

    return Meteor.Router.commentIdPath commentId unless comment

    publicationSlug = comment.publication?.slug
    unless publicationSlug?
      publication = Publication.documents.findOne comment.publication._id
      publicationSlug = publication?.slug

      return Meteor.Router.commentIdPath commentId unless publicationSlug?

    Meteor.Router.commentPath comment.publication._id, publicationSlug, commentId

  path: =>
    @constructor.pathFromId @_id

  route: =>
    source: @constructor.verboseName()
    route: 'comment'
    params:
      publicationId: @publication?._id
      publicationSlug: @publication?.slug
      commentId: @_id

  # Helper object with properties useful to refer to this document. Optional group document.
  @reference: (commentId, comment) ->
    assert _.isString commentId

    comment = @documents.findOne commentId unless comment
    assert commentId, comment._id if comment

    _id: commentId # TODO: Remove when we will be able to access parent template context
    text: "m:#{ commentId }"

  reference: =>
    @constructor.reference @_id, @

Template.registerHelper 'isComment', ->
  @ instanceof Comment

Template.registerHelper 'commentPathFromId', _.bind Comment.pathFromId, Comment

Template.registerHelper 'commentReference', _.bind Comment.reference, Comment
