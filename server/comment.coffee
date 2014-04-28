class @Comment extends Comment
  @Meta
    name: 'Comment'
    replaceParent: true

  # A set of fields which are public and can be published to the client
  @PUBLISH_FIELDS: ->
    fields: {} # All

Meteor.methods
  'comments-path': (commentId) ->
    check commentId, DocumentId

    person = Meteor.person()

    # No need for requireReadAccessSelector because comments are public
    comment = Comment.documents.findOne
      _id: commentId
    return unless comment

    annotation = Annotation.documents.findOne Annotation.requireReadAccessSelector(person,
      _id: comment.annotation._id
    )
    return unless annotation

    assert.equal comment.publication._id, annotation.publication._id

    publication = Publication.documents.findOne Publication.requireReadAccessSelector(person,
      _id: annotation.publication._id
    )
    return unless publication

    [publication._id, publication.slug, comment._id]

  'create-comment': (annotationId, body) ->
    check annotationId, DocumentId
    check body, NonEmptyString

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    # TODO: Verify if body is valid HTML and does not contain anything we do not allow
    # TODO: Parse and store references in comment's body

    annotation = Annotation.documents.findOne Annotation.requireReadAccessSelector(person,
      _id: annotationId
    )
    throw new Meteor.Error 400, "Invalid annotation." unless annotation

    publication = Publication.documents.findOne Publication.requireReadAccessSelector(person,
      _id: annotation.publication._id
    )
    throw new Meteor.Error 400, "Invalid annotation." unless publication

    createdAt = moment.utc().toDate()
    comment =
      createdAt: createdAt
      updatedAt: createdAt
      author:
        _id: person._id
      annotation:
        _id: annotationId
      publication:
        _id: annotation.publication._id
      body: body
      license: 'CC0-1.0+'

    comment = Comment.applyDefaultAccess person._id, comment

    Comment.documents.insert comment

  # TODO: Use this code on the client side as well
  'remove-comment': (commentId) ->
    check commentId, DocumentId

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    comment = Comment.documents.findOne
      _id: commentId
    throw new Meteor.Error 400, "Invalid comment." unless comment

    annotation = Annotation.documents.findOne Annotation.requireReadAccessSelector(person,
      _id: comment.annotation._id
    )
    throw new Meteor.Error 400, "Invalid comment." unless annotation

    publication = Publication.documents.findOne Publication.requireReadAccessSelector(person,
      _id: annotation.publication._id
    )
    throw new Meteor.Error 400, "Invalid comment." unless publication

    Comment.documents.remove Comment.requireRemoveAccessSelector(person,
      _id: comment._id
    )

Meteor.publish 'comments-by-publication', (publicationId) ->
  check publicationId, DocumentId

  @related (person, publication) ->
    return unless publication?.hasReadAccess person
    # TODO: We have also to limit only to comments on annotations user has access to
    # TODO: Assert that comment.publication._id == annotation.publication._id (make a query which returns only valid?)

    # No need for requireReadAccessSelector because comments are public
    Comment.documents.find
      'publication._id': publication._id
    ,
      Comment.PUBLISH_FIELDS()
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: Publication.readAccessPersonFields()
  ,
    Publication.documents.find
      _id: publicationId
    ,
      fields: Publication.readAccessSelfFields()
