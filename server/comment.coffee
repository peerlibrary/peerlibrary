class @Comment extends Comment
  @Meta
    name: 'Comment'
    replaceParent: true

  # A set of fields which are public and can be published to the client
  @PUBLIC_FIELDS: ->
    fields: {} # All

Meteor.methods
  'create-comment': (annotationId, body) ->
    check annotationId, DocumentId
    check body, NonEmptyString

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    # TODO: Verify if body is valid HTML and does not contain anything we do not allow

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
      _id: commentId
    )

Meteor.publish 'comments-by-publication', (publicationId) ->
  check publicationId, DocumentId

  @related (person, publication) ->
    return unless publication?.hasReadAccess person
    # TODO: We have also to limit only to comments on annotations user has access to

    # No need for requireReadAccessSelector because comments are public
    Comment.documents.find
      'publication._id': publicationId
    ,
      Comment.PUBLIC_FIELDS()
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
