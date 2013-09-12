Accounts.onCreateUser (options, user) ->
  try
    person =
      user:
        id: user._id
        username: user.username
      slug: user.username

    if options.profile
      person.foreNames = options.profile.foreNames if options.profile.foreNames?
      person.lastName = options.profile.lastName if options.profile.lastName?
      person.work = options.profile.work if options.profile.work?
      person.education = options.profile.education if options.profile.education?
      person.publications = options.profile.publications if options.profile.publications?

    personId = Persons.insert person
    user.person =
      id: personId
  catch e
    if e.name isnt 'MongoError'
      throw e
    # TODO: Improve when https://jira.mongodb.org/browse/SERVER-3069
    if /E11000 duplicate key error index:.*Persons\.\$slug/.test e.err
      throw new Meteor.Error 403, 'Username conflicts with existing slug.'
    throw e
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