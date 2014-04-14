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

  # A subset of public fields used for automatic publishing
  # This list is applied to PUBLIC_FIELDS to get a subset
  @PUBLIC_AUTO_FIELDS: ->
    [
      'user'
      'slug'
      'gravatarHash'
      'givenName'
      'familyName'
      'isAdmin'
      'inGroups'
    ]

  # A set of fields which are public and can be published to the client
  @PUBLIC_FIELDS: ->
    fields:
      user: 1
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

Meteor.methods
  'reorder-library': (publicationIds) ->
    check publicationIds, [String]

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    library = _.pluck person.library, '_id'

    throw new Meteor.Error 400, "Provided Ids don't match." if _.difference(library, publicationIds).length

    publications = (_id: publicationId for publicationId in publicationIds)

    Person.documents.update
      _id: person._id
    ,
      $set:
        library: publications

Meteor.publish 'persons-by-id-or-slug', (slug) ->
  check slug, String

  return unless slug

  Person.documents.find
    $or: [
        slug: slug
      ,
        _id: slug
      ]
    ,
      Person.PUBLIC_FIELDS()

Meteor.publish 'search-persons', (query, except) ->
  except ?= []

  check query, String
  check except, [String]

  return unless query

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
    cursor: Person.documents.find findPersonQuery,
      limit: 5
      fields: Person.PUBLIC_FIELDS().fields

Person.Meta.collection._ensureIndex 'slug',
  unique: 1
