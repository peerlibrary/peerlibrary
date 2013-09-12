Accounts.onCreateUser (options, user) ->
  try
    person =
      user:
        id: user._id
        username: user.username
      slug: user.username

    person.foreNames = if options.foreNames then options.foreNames else null
    person.lastName = if options.lastName then options.lastName else null
    person.work = if options.work then options.work else null
    person.education = if options.education then options.education else null
    person.publications = if options.publications then options.publications else null

    personId = Persons.insert person
    user.person = personId
  catch e
    throw new Meteor.Error 403, 'Username conflicts with existing slug.'
  user

Meteor.publish 'users-by-username', (username) ->
  Meteor.users.find
      username: username
    ,
      fields:
        username: 1
        person: 1

Meteor.publish 'persons-by-slug', (slug) ->
  Persons.find
    $or: [
        _id: slug
      ,
        'user.username': slug
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