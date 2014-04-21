class @Annotation extends Annotation
  @Meta
    name: 'Annotation'
    replaceParent: true

  # A set of fields which are public and can be published to the client
  @PUBLISH_FIELDS: ->
    fields: {} # All

registerForAccess Annotation

Meteor.methods
  'annotations-path': (annotationId) ->
    check annotationId, DocumentId

    person = Meteor.person()

    annotation = Annotation.documents.findOne Annotation.requireReadAccessSelector(person,
      _id: annotationId
    )
    return unless annotation

    publication = Publication.documents.findOne Publication.requireReadAccessSelector(person,
      _id: annotation.publication._id
    )
    return unless publication

    [publication._id, publication.slug, annotationId]

  'create-annotation': (publicationId, body) ->
    check publicationId, DocumentId
    check body, Match.Optional NonEmptyString

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    # TODO: Verify if body is valid HTML and does not contain anything we do not allow

    body = '' unless body

    publication = Publication.documents.findOne Publication.requireReadAccessSelector(person,
      _id: publicationId
    )
    throw new Meteor.Error 400, "Invalid publication." unless publication

    # TODO: Should we sync this somehow with createAnnotationDocument? Maybe move createAnnotationDocument to Annotation object?
    createdAt = moment.utc().toDate()
    annotation =
      createdAt: createdAt
      updatedAt: createdAt
      author:
        _id: person._id
      publication:
        _id: publicationId
      references:
        highlights: []
        annotations: []
        publications: []
        persons: []
        tags: []
      tags: []
      body: body
      license: 'CC0-1.0+'

    annotation = Annotation.applyDefaultAccess person._id, annotation

    Annotation.documents.insert annotation

  # TODO: Use this code on the client side as well
  'update-annotation-body': (annotationId, body) ->
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

    Annotation.documents.update Annotation.requireMaintainerAccessSelector(person,
      _id: annotationId
    ),
      $set:
        updatedAt: moment.utc().toDate()
        body: body

  # TODO: Use this code on the client side as well
  'remove-annotation': (annotationId) ->
    check annotationId, DocumentId

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    annotation = Annotation.documents.findOne Annotation.requireReadAccessSelector(person,
      _id: annotationId
    )
    throw new Meteor.Error 400, "Invalid annotation." unless annotation

    publication = Publication.documents.findOne Publication.requireReadAccessSelector(person,
      _id: annotation.publication._id
    )
    throw new Meteor.Error 400, "Invalid annotation." unless publication

    Annotation.documents.remove Annotation.requireRemoveAccessSelector(person,
      _id: annotationId
    )

Meteor.publish 'annotations-by-publication', (publicationId) ->
  check publicationId, DocumentId

  @related (person, publication) ->
    return unless publication?.hasReadAccess person

    Annotation.documents.find Annotation.requireReadAccessSelector(person,
      'publication._id': publicationId
    ), Annotation.PUBLISH_FIELDS()
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: _.extend Annotation.readAccessPersonFields(), Publication.readAccessPersonFields()
  ,
    Publication.documents.find
      _id: publicationId
    ,
      fields: Publication.readAccessSelfFields()
