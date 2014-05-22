url = Npm.require 'url'

class @Annotation extends Annotation
  @Meta
    name: 'Annotation'
    replaceParent: true

  # A set of fields which are public and can be published to the client
  @PUBLISH_FIELDS: ->
    fields: {} # All

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

    [publication._id, publication.slug, annotation._id]

  'create-annotation': (publicationId, body, access, groups) ->
    check publicationId, DocumentId
    check body, Match.Optional NonEmptyString
    check access, MatchAccess Annotation.ACCESS
    check groups, [DocumentId]

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
    throw new Meteor.Error 400, "Invalid groups." if _.difference(groups, personGroups).length

    throw new Meteor.Error 400, "Invalid groups." if Group.documents.find(Group.requireReadAccessSelector(person,
      _id:
        $in: groups
    )).count() isnt groups.length

    groups = (_id: groupId for groupId in groups)

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
      inside: groups
      readGroups: groups
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
        updatedAt: moment.utc().toDate()
        body: body
        references: references

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
      _id: annotation._id
    )

Meteor.publish 'annotations-by-publication', (publicationId) ->
  check publicationId, DocumentId

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
  check limit, PositiveNumber
  check filter, OptionalOrNull String
  check sortIndex, OptionalOrNull Number
  check sortIndex, Match.Where ->
    not _.isNumber(sortIndex) or sortIndex < Annotation.PUBLISH_CATALOG_SORT.length

  findQuery = {}
  findQuery = _.extend findQuery, createQueryCriteria(filter, 'body') if filter

  sort = if _.isNumber sortIndex then Annotation.PUBLISH_CATALOG_SORT[sortIndex].sort else null

  @related (person) ->
    restrictedFindQuery = Annotation.requireReadAccessSelector person, findQuery

    searchPublish @, 'annotations', [filter, sortIndex],
      cursor: Annotation.documents.find(restrictedFindQuery,
        limit: limit
        fields: Annotation.PUBLISH_FIELDS().fields
        sort: sort
      )
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: _.extend Group.readAccessPersonFields()
