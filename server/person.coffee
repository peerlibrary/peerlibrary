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

      fields.displayName.generator = (fields) ->
        person = new Person fields
        # Display name is public, so we don't want to leak email until the user registers.
        # We use a special publish endpoint to provide email addresses of all invitees to inviters.
        if person.user.refresh(services: 1).isRegistered()
          [fields._id, person.getDisplayName true]
        else
          [fields._id, fields._id]

      fields.gravatarHash.generator = (fields) ->
        # Hash should come from user's email
        source = fields.emails?[0]?.address

        # Alternatively, if no email, use the display name
        source = fields.person?.displayName unless source

        return [null, undefined] unless fields.person?._id and source
        [fields.person._id, crypto.createHash('md5').update(source).digest('hex')]

      fields

  # A set of fields which are public and can be published to the client
  @PUBLISH_FIELDS: ->
    fields:
      'user._id': 1
      'user.username': 1
      slug: 1
      displayName: 1
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
    fields: _.pick @PUBLISH_FIELDS().fields, [
      'user._id'
      'user.username'
      'slug'
      'displayName'
      'gravatarHash'
      'isAdmin'
      'inGroups'
    ]

  # A subset of public fields used for catalog results
  @PUBLISH_CATALOG_FIELDS: ->
    fields: _.pick @PUBLISH_FIELDS().fields, [
      'user._id'
      'user.username'
      'slug'
      'displayName'
      'gravatarHash'
      'isAdmin'
      'inGroups'
    ]

# With null name, the record set is automatically sent to all connected clients
Meteor.publish null, ->
  return unless @personId

  # No need for requireReadAccessSelector because we are sending data to the person themselves
  Person.documents.find
    _id: @personId
  ,
    Person.PUBLISH_AUTO_FIELDS()

Meteor.publish 'persons-by-ids-or-slugs', (idsOrSlugs) ->
  validateArgument 'idsOrSlugs', idsOrSlugs, Match.OneOf NonEmptyString, [NonEmptyString]

  idsOrSlugs = [idsOrSlugs] unless _.isArray idsOrSlugs

  # No need for requireReadAccessSelector because persons are public
  Person.documents.find
    $or: [
      slug:
        $in: idsOrSlugs
    ,
      _id:
        $in: idsOrSlugs
    ]
  ,
    Person.PUBLISH_FIELDS()

# User who invited should have access to email address so that
# we can display it in lists to which user was added when invited
Meteor.publish 'persons-invited', ->
  # No need for requireReadAccessSelector because persons are public
  handle = Person.documents.find(
    'invited.by._id': @personId
  ,
    fields:
      'user.emails': 1
  ).observeChanges
    added: (id, fields) =>
      @added 'Persons', id,
        invitedEmail: new Person(_.extend {}, {_id: id}, fields).email()
    changed: (id, fields) =>
      @changed 'Persons', id,
        invitedEmail: new Person(_.extend {}, {_id: id}, fields).email()
    removed: (id) =>
      @removed 'Persons', id

  @ready()

  @onStop ->
    handle.stop()

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

  validateArgument 'query', query, NonEmptyString
  validateArgument 'except', except, [DocumentId]

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

Person.Meta.collection._ensureIndex
  slug: 1
,
  unique: 1

Meteor.publish 'persons', (limit, filter, sortIndex) ->
  validateArgument 'limit', limit, PositiveNumber
  validateArgument 'filter', filter, OptionalOrNull String
  validateArgument 'sortIndex', sortIndex, OptionalOrNull Number
  validateArgument 'sortIndex', sortIndex, Match.Where (sortIndex) ->
    not _.isNumber(sortIndex) or 0 <= sortIndex < Person.PUBLISH_CATALOG_SORT.length

  findQuery = {}
  findQuery = createQueryCriteria(filter, 'displayName') if filter

  sort = if _.isNumber sortIndex then Person.PUBLISH_CATALOG_SORT[sortIndex].sort else null

  searchPublish @, 'persons', [filter, sortIndex],
    cursor: Person.documents.find findQuery,
      limit: limit
      fields: Person.PUBLISH_CATALOG_FIELDS().fields
      sort: sort

ensureCatalogSortIndexes Person
