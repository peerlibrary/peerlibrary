crypto = Npm.require 'crypto'

class @Person extends Person
  @Meta
    name: 'Person'
    replaceParent: true
    fields: (fields) =>
      fields.slug.generator = (fields) ->
        if fields.user?.username
          [fields._id, fields.user.username]
        else
          [fields._id, fields._id]
      fields.gravatarHash.generator = (fields) ->
        address = fields.emails?[0]?.address
        return [null, undefined] unless fields.person?._id and address

        [fields.person._id, crypto.createHash('md5').update(address).digest('hex')]
      fields

  # A set of fields which are public and can be published to the client
  @PUBLISH_FIELDS: ->
    fields:
      'user._id': 1
      'user.username': 1
      slug: 1
      gravatarHash: 1
      givenName: 1
      familyName: 1
      isAdmin: 1
      inGroups: 1
      work: 1
      education: 1
      publications: 1
      library: 1

  # A subset of public fields used for automatic publishing
  @PUBLISH_AUTO_FIELDS: ->
    fields: _.extend _.pick(@PUBLISH_FIELDS().fields, [
      'user._id'
      'user.username'
      'slug'
      'gravatarHash'
      'givenName'
      'familyName'
      'isAdmin'
      'inGroups'
    ]),
      # Additionally, provide email address so that displayName can
      # display something meaningful for users who have been invited
      'user.emails': 1

Meteor.publish 'persons-by-id-or-slug', (slug) ->
  check slug, NonEmptyString

  # No need for requireReadAccessSelector because persons are public
  Person.documents.find
    $or: [
      slug: slug
    ,
      _id: slug
    ]
  ,
    Person.PUBLISH_FIELDS()

# TODO: Should we really publish whole person documents, because this publish endpoint exists just to get access to email address to display it in lists to which user was added when invited?
Meteor.publish 'persons-invited', ->
  @related (person) ->
    return unless person?._id

    # No need for requireReadAccessSelector because persons are public
    Person.documents.find
      invitedBy:
        _id: person._id
    ,
      fields: _.extend Person.PUBLISH_FIELDS().fields,
        # User who invited should have access to email address so that
        # we can display it in lists to which user was added when invited
        'user.emails': 1
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: Publication.readAccessPersonFields()

Meteor.publish 'my-person-library', ->
  return unless @personId

  # No need for requireReadAccessSelector because persons are public
  Person.documents.find
    _id: @personId
  ,
    fields:
      library: 1

Meteor.publish 'search-persons', (query, except) ->
  except ?= []

  check query, NonEmptyString
  check except, [DocumentId]

  keywords = (keyword.replace /[-\\^$*+?.()|[\]{}]/g, '\\$&' for keyword in query.split /\s+/)

  findPersonQuery =
    $and: []
    _id:
      $nin: except

  # TODO: Use some smarter searching with provided query, probably using some real full-text search instead of regex
  for keyword in keywords when keyword
    regex = new RegExp keyword, 'i'
    findPersonQuery.$and.push
      $or: [
        _id: keyword
      ,
        'user.username': regex
      ,
        'user.emails.0.address': regex
      ,
        givenName: regex
      ,
        familyName: regex
      ]

  return unless findPersonQuery.$and.length

  searchPublish @, 'search-persons', query,
    # No need for requireReadAccessSelector because persons are public
    cursor: Person.documents.find findPersonQuery,
      limit: 5
      # TODO: Optimize fields, we do not need all
      fields: Person.PUBLISH_FIELDS().fields

Person.Meta.collection._ensureIndex 'slug',
  unique: 1
