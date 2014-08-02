class @Comment extends Comment
  @Meta
    name: 'Comment'
    replaceParent: true

  # If we have the comment and the publication available on the client,
  # we can create full path directly, otherwise we have to use commentIdPath
  @pathFromId: (commentId, options) ->
    assert _.isString commentId

    comment = @documents.findOne commentId

    return Meteor.Router.commentIdPath commentId unless comment

    publicationSlug = comment.publication?.slug
    unless publicationSlug?
      publication = Publication.documents.findOne comment.publication._id
      publicationSlug = publication?.slug

      return Meteor.Router.commentIdPath commentId unless publicationSlug?

    Meteor.Router.commentPath comment.publication._id, publicationSlug, commentId

  path: ->
    @constructor.pathFromId @_id

  # Helper object with properties useful to refer to this document
  # Optional comment document
  @reference: (commentId, comment, options) ->
    assert _.isString commentId
    # To allow calling template helper with only one argument (comment will be options then)
    comment = null unless comment instanceof @

    comment = @documents.findOne commentId unless comment
    assert commentId, comment._id if comment

    _id: commentId # TODO: Remove when we will be able to access parent template context
    text: "m:#{ commentId }"

  reference: ->
    @constructor.reference @_id, @

Handlebars.registerHelper 'commentPathFromId', _.bind Comment.pathFromId, Comment

Handlebars.registerHelper 'commentReference', _.bind Comment.reference, Comment
