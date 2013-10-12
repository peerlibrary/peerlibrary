class @Person extends @Person
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
