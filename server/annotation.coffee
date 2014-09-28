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
    validateArgument 'annotationId', annotationId, DocumentId

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
    validateArgument 'publicationId', publicationId, DocumentId
    validateArgument 'body', body, Match.Optional NonEmptyString
    validateArgument 'access', access, MatchAccess Annotation.ACCESS
    validateArgument 'workInsideGroups', workInsideGroups, [DocumentId]
    validateArgument 'readPersons', readPersons, [DocumentId]
    validateArgument 'readGroups', readGroups, [DocumentId]
    validateArgument 'maintainerPersons', maintainerPersons, [DocumentId]
    validateArgument 'maintainerGroups', maintainerGroups, [DocumentId]
    validateArgument 'adminPersons', adminPersons, [DocumentId]
    validateArgument 'adminGroups', adminGroups, [DocumentId]

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    # TODO: We should not allow empty body, but until we have drafts we have to
    body = '' unless body
    body = cleanBlockHTML body

    # TODO: Verify that text content all together, trimmed of space, is non-empty

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
    validateArgument 'annotationId', annotationId, DocumentId
    validateArgument 'body', body, NonEmptyString

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    body = cleanBlockHTML body

    # TODO: Verify that text content all together, trimmed of space, is non-empty

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
    validateArgument 'DocumentId', annotationId, DocumentId

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

new PublishEndpoint 'annotations-by-publication', (publicationId) ->
  validateArgument 'publicationId', publicationId, DocumentId

  @related (person, publication) ->
    return unless publication?.hasReadAccess person

    # We store related fields so that they are available in middlewares.
    @set 'person', person
    @set 'publication', publication

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

new PublishEndpoint 'annotations', (limit, filter, sortIndex) ->
  validateArgument 'limit', limit, PositiveNumber
  validateArgument 'filter', filter, OptionalOrNull String
  validateArgument 'sortIndex', sortIndex, OptionalOrNull Number
  validateArgument 'sortIndex', sortIndex, Match.Where (sortIndex) ->
    not _.isNumber(sortIndex) or 0 <= sortIndex < Annotation.PUBLISH_CATALOG_SORT.length

  findQuery = {}
  findQuery = createQueryCriteria(filter, 'body') if filter

  sort = if _.isNumber sortIndex then Annotation.PUBLISH_CATALOG_SORT[sortIndex].sort else null

  @related (person) ->
    # We store related fields so that they are available in middlewares.
    @set 'person', person

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

ensureCatalogSortIndexes Annotation
