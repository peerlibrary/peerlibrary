class @Comment extends Comment
  @Meta
    name: 'Comment'
    replaceParent: true

  # A set of fields which are public and can be published to the client
  @PUBLIC_FIELDS: ->
    fields: {} # All

Meteor.methods
  # TODO: Use this code on the client side as well
  'create-comment': (annotationId, body) ->
    check annotationId, DocumentId
    check body, NonEmptyString

    throw new Meteor.Error 401, "User not signed in." unless Meteor.personId()

    # TODO: Verify if body is valid HTML and does not contain anything we do not allow

    annotation = Annotation.documents.findOne Annotation.requireReadAccessSelector(Meteor.person(),
      _id: annotationId
    )
    throw new Meteor.Error 400, "Invalid annotation." unless annotation

    createdAt = moment.utc().toDate()
    comment =
      createdAt: createdAt
      updatedAt: createdAt
      author:
        _id: Meteor.personId()
      annotation:
        _id: annotationId
      publication:
        _id: annotation.publication._id
      body: body
      license: 'CC0-1.0+'

    comment = Comment.applyDefaultAccess Meteor.personId(), comment

    Comment.documents.insert comment

Meteor.publish 'comments-by-publication', (publicationId) ->
  check publicationId, DocumentId

  Comment.documents.find
    'publication._id': publicationId
  ,
    Comment.PUBLIC_FIELDS()
