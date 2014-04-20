class @Annotation extends Annotation
  @Meta
    name: 'Annotation'
    replaceParent: true

  # A set of fields which are public and can be published to the client
  @PUBLIC_FIELDS: ->
    fields: {} # All

registerForAccess Annotation

Meteor.methods
  'annotations-path': (annotationId) ->
    check annotationId, String

    annotation = Annotation.documents.findOne Annotation.requireReadAccessSelector(Meteor.person(),
      _id: annotationId
    )
    return unless annotation

    publication = Publication.documents.findOne Publication.requireReadAccessSelector(Meteor.person(),
      _id: annotation.publication._id
    )
    return unless publication

    [publication._id, publication.slug, annotationId]

  # TODO: Use this code on the client side as well
  'create-annotation': (publicationId, body) ->
    check publicationId, String
    check body, Match.Optional String

    throw new Meteor.Error 401, "User not signed in." unless Meteor.personId()

    # TODO: Verify if body is valid HTML and does not contain anything we do not allow

    body = '' unless body

    publication = Publication.documents.findOne Publication.requireReadAccessSelector(Meteor.person(),
      _id: publicationId
    )
    throw new Meteor.Error 400, "Invalid publication." unless publication

    # TODO: Should we sync this somehow with createAnnotationDocument? Maybe move createAnnotationDocument to Annotation object?
    createdAt = moment.utc().toDate()
    annotation =
      createdAt: createdAt
      updatedAt: createdAt
      author:
        _id: Meteor.personId()
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

    annotation = Annotation.applyDefaultAccess Meteor.personId(), annotation

    console.log "before"
    id = Annotation.documents.insert annotation
    console.log "after"
    id

  # TODO: Use this code on the client side as well
  'update-annotation-body': (annotationId, body) ->
    check annotationId, String
    check body, String

    throw new Meteor.Error 401, "User not signed in." unless Meteor.personId()

    # TODO: Verify if body is valid HTML and does not contain anything we do not allow

    throw new Meteor.Error 400, "Invalid body." unless body

    # TODO: Check permissions (or simply limit query to them)

    Annotation.documents.update
      _id: annotationId
    ,
      $set:
        updatedAt: moment.utc().toDate()
        body: body

  'remove-annotation': (annotationId) ->
    check annotationId, String

    throw new Meteor.Error 401, "User not signed in." unless Meteor.personId()

    # TODO: Check permissions (or simply limit query to them)

    Annotation.documents.remove annotationId

Meteor.publish 'annotations-by-id', (id) ->
  check id, String

  return unless id

  @related (person, publication) ->
    return unless publication?.hasReadAccess person

    Annotation.documents.find Annotation.requireReadAccessSelector(person,
      _id: id
    ), Annotation.PUBLIC_FIELDS()
  ,
    Person.documents.find
      _id: @personId
    ,
      fields:
        # _id field is implicitly added
        isAdmin: 1
        inGroups: 1
        library: 1 # Needed by hasReadAccess
  ,
    Publication.documents.find
      'annotations._id': id
    ,
      fields:
        # _id field is implicitly added
        cached: 1
        processed: 1
        access: 1
        readPersons: 1
        readGroups: 1

Meteor.publish 'annotations-by-publication', (publicationId) ->
  check publicationId, String

  return unless publicationId

  @related (person, publication) ->
    return unless publication?.hasReadAccess person

    Annotation.documents.find Annotation.requireReadAccessSelector(person,
      'publication._id': publicationId
    ), Annotation.PUBLIC_FIELDS()
  ,
    Person.documents.find
      _id: @personId
    ,
      fields:
        # _id field is implicitly added
        isAdmin: 1
        inGroups: 1
        library: 1 # Needed by hasReadAccess
  ,
    Publication.documents.find
      _id: publicationId
    ,
      fields:
        # _id field is implicitly added
        cached: 1
        processed: 1
        access: 1
        readPersons: 1
        readGroups: 1
