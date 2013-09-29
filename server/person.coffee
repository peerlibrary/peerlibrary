Meteor.publish 'persons-by-id-or-slug', (slug) ->
  Persons.find
    $or: [
        slug: slug
      ,
        _id: slug
      ]
    ,
      fields:
        user: 1
        slug: 1
        foreNames: 1
        lastName: 1
        work: 1
        education: 1
        publications: 1

Persons._ensureIndex 'slug',
  unique: 1
