crypto = Npm.require 'crypto'

class @Person extends @Person
  @MixinMeta (meta) =>
    meta.fields.slug.generator = (fields) ->
      if fields.user?.username
        [fields._id, fields.user.username]
      else
        [fields._id, fields._id]
    meta.fields.gravatarHash.generator = (fields) ->
      address = fields.emails?[0]?.address
      return [null, undefined] unless fields.person?._id and address

      [fields.person._id, crypto.createHash('md5').update(address).digest('hex')]
    meta

  # A subset of public fields used for automatic publishing
  # This list is applied to PUBLIC_FIELDS to get a subset
  @PUBLIC_AUTO_FIELDS: ->
    [
      'user'
      'slug'
      'gravatarHash'
      'foreNames'
      'lastName'
    ]

  # A set of fields which are public and can be published to the client
  @PUBLIC_FIELDS: ->
    fields:
      user: 1
      slug: 1
      gravatarHash: 1
      foreNames: 1
      lastName: 1
      work: 1
      education: 1
      publications: 1

Meteor.publish 'persons-by-id-or-slug', (slug) ->
  Persons.find
    $or: [
        slug: slug
      ,
        _id: slug
      ]
    ,
      Person.PUBLIC_FIELDS()

Persons._ensureIndex 'slug',
  unique: 1
