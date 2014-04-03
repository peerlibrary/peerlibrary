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
      work: 1
      education: 1
      publications: 1
      library: 1

Meteor.methods
  'reorder-library': (publications) ->
    check publications, [String]

    #TODO: This code does not work and corrupts Person records. Please correct.

    personId = Meteor.personId
    return unless personId

    Person.documents.update
      _id: personId
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

Person.Meta.collection._ensureIndex 'slug',
  unique: 1
