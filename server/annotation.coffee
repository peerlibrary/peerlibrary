url = Npm.require 'url'

class @Annotation extends Annotation
  @Meta
    name: 'Annotation'
    replaceParent: true
    fields: (fields) =>
      fields.commentsCount.generator = (fields) ->
        [fields._id, fields.comments?.length or 0]

      fields

  # A set of fields which are public and can be published to the client
  @PUBLISH_FIELDS: ->
    fields:
      # We are sending only the count over, not all comments
      comments: 0

  # A subset of public fields used for catalog results
  @PUBLISH_CATALOG_FIELDS: ->
    fields:
      author: 1
      body: 1
      publication: 1
      commentsCount: 1

registerForAccess Annotation

# TODO: This parsing could be done through PeerDB instead, on any body field change
parseReferences = (body) ->
  references =
    highlights: []
    annotations: []
    publications: []
    persons: []
    groups: []
    tags: []
    collections: []
    comments: []
    urls: []

  $ = cheerio.load body
  $.root().find('a').each (i, a) =>
    href = $(a).attr('href')

    {referenceName, referenceId} = parseURL(href) or {}

    return unless referenceName and referenceId and references["#{ referenceName }s"]

    references["#{ referenceName }s"].push
      _id: referenceId

    return # Make sure CoffeeScript does not return anything

  references

Meteor.methods
  'annotations-path': methodWrap (annotationId) ->
    validateArgument annotationId, DocumentId, 'annotationId'

    person = Meteor.person()

    annotation = Annotation.documents.findOne Annotation.requireReadAccessSelector(person,
      _id: annotationId
    )
    return unless annotation

    publication = Publication.documents.findOne Publication.requireReadAccessSelector(person,
      _id: annotation.publication._id
    )
    return unless publication

    [publication._id, publication.slug, annotation._id]

  'create-annotation': methodWrap (publicationId, body, access, workInsideGroups, readPersons, readGroups, maintainerPersons, maintainerGroups, adminPersons, adminGroups) ->
    validateArgument publicationId, DocumentId, 'publicationId'
    validateArgument body, Match.Optional (NonEmptyString), 'body'
    validateArgument access, (MatchAccess Annotation.ACCESS), 'access'
    validateArgument workInsideGroups, [DocumentId], 'workInsideGroups'
    validateArgument readPersons, [DocumentId], 'readPersons'
    validateArgument readGroups, [DocumentId], 'readGroups'
    validateArgument maintainerPersons, [DocumentId], 'maintainerPersons'
    validateArgument maintainerGroups, [DocumentId], 'maintainerGroups'
    validateArgument adminPersons, [DocumentId], 'adminPersons'
    validateArgument adminGroups, [DocumentId], 'adminGroups'

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    # TODO: Verify if body is valid HTML and does not contain anything we do not allow

    body = '' unless body

    references = parseReferences body

    publication = Publication.documents.findOne Publication.requireReadAccessSelector(person,
      _id: publicationId
    )
    throw new Meteor.Error 400, "Invalid publication." unless publication

    personGroups = _.pluck person.inGroups, '_id'
    throw new Meteor.Error 400, "Invalid work-inside groups." if _.difference(workInsideGroups, personGroups).length

    throw new Meteor.Error 400, "Invalid work-inside groups." if Group.documents.find(Group.requireReadAccessSelector person,
      _id:
        $in: workInsideGroups
    ).count() isnt workInsideGroups.length

    throw new Meteor.Error 400, "Invalid read persons." if Person.documents.find(
      _id:
        $in: readPersons
    ).count() isnt readPersons.length

    throw new Meteor.Error 400, "Invalid read groups." if Group.documents.find(Group.requireReadAccessSelector person,
      _id:
        $in: readGroups
    ).count() isnt readGroups.length

    throw new Meteor.Error 400, "Invalid maintainer persons." if Person.documents.find(
      _id:
        $in: maintainerPersons
    ).count() isnt maintainerPersons.length

    throw new Meteor.Error 400, "Invalid maintainer groups." if Group.documents.find(Group.requireReadAccessSelector person,
      _id:
        $in: maintainerGroups
    ).count() isnt maintainerGroups.length

    throw new Meteor.Error 400, "Invalid admin persons." if Person.documents.find(
      _id:
        $in: adminPersons
    ).count() isnt adminPersons.length

    throw new Meteor.Error 400, "Invalid admin groups." if Group.documents.find(Group.requireReadAccessSelector person,
      _id:
        $in: adminGroups
    ).count() isnt adminGroups.length

    workInsideGroups = (_id: groupId for groupId in workInsideGroups)
    readPersons = (_id: personId for personId in readPersons)
    readGroups = (_id: groupId for groupId in readGroups)
    maintainerPersons = (_id: personId for personId in maintainerPersons)
    maintainerGroups = (_id: groupId for groupId in maintainerGroups)
    adminPersons = (_id: personId for personId in adminPersons)
    adminGroups = (_id: groupId for groupId in adminGroups)

    # TODO: Should we sync this somehow with createAnnotationDocument? Maybe move createAnnotationDocument to Annotation object?
    createdAt = moment.utc().toDate()
    annotation =
      createdAt: createdAt
      updatedAt: createdAt
      author:
        _id: person._id
      publication:
        _id: publicationId
      references: references
      tags: []
      body: body
      access: access
      inside: workInsideGroups
      readPersons: readPersons
      readGroups: readGroups
      maintainerPersons: maintainerPersons
      maintainerGroups: maintainerGroups
      adminPersons: adminPersons
      adminGroups: adminGroups
      license: 'CC0-1.0+'

    annotation = Annotation.applyDefaultAccess person._id, annotation

    Annotation.documents.insert annotation

  # TODO: Use this code on the client side as well
  'update-annotation-body': methodWrap (annotationId, body) ->
    validateArgument annotationId, DocumentId, 'annotationId'
    validateArgument body, NonEmptyString, 'body'

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    # TODO: Verify if body is valid HTML and does not contain anything we do not allow

    references = parseReferences body

    annotation = Annotation.documents.findOne Annotation.requireReadAccessSelector(person,
      _id: annotationId
    )
    throw new Meteor.Error 400, "Invalid annotation." unless annotation

    publication = Publication.documents.findOne Publication.requireReadAccessSelector(person,
      _id: annotation.publication._id
    )
    throw new Meteor.Error 400, "Invalid annotation." unless publication

    Annotation.documents.update Annotation.requireMaintainerAccessSelector(person,
      _id: annotation._id
    ),
      $set:
        body: body
        references: references

  # TODO: Use this code on the client side as well
  'remove-annotation': methodWrap (annotationId) ->
    validateArgument annotationId, DocumentId, 'DocumentId'

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
      _id: annotation._id
    )

Meteor.publish 'annotations-by-publication', (publicationId) ->
  validateArgument publicationId, DocumentId, 'publicationId'

  @related (person, publication) ->
    return unless publication?.hasReadAccess person

    Annotation.documents.find Annotation.requireReadAccessSelector(person,
      'publication._id': publication._id
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

Meteor.publish 'annotations', (limit, filter, sortIndex) ->
  validateArgument limit, PositiveNumber, 'limit'
  validateArgument filter, OptionalOrNull (String), 'filter'
  validateArgument sortIndex, OptionalOrNull (Number), 'sortIndex'
  validateArgument sortIndex, (Match.Where ->
    not _.isNumber(sortIndex) or 0 <= sortIndex < Annotation.PUBLISH_CATALOG_SORT.length), 'sortIndex'

  findQuery = {}
  findQuery = createQueryCriteria(filter, 'body') if filter

  sort = if _.isNumber sortIndex then Annotation.PUBLISH_CATALOG_SORT[sortIndex].sort else null

  @related (person) ->
    restrictedFindQuery = Annotation.requireReadAccessSelector person, findQuery

    searchPublish @, 'annotations', [filter, sortIndex],
      cursor: Annotation.documents.find restrictedFindQuery,
        limit: limit
        fields: Annotation.PUBLISH_CATALOG_FIELDS().fields
        sort: sort
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: _.extend Annotation.readAccessPersonFields()
