Accounts.onCreateUser (options, user) ->
  if options.profile
    user.profile = options.profile
  else
    try
      personId = Persons.insert
        user:
          id: user._id
          username: user.username
        slug: user.username
      user.profile =
        person: personId
    catch e
      throw new Meteor.Error 403, 'Username conflicts with existing slug.'
  user

Meteor.publish 'users-by-username', (username) ->
  Meteor.users.find
      username: username
    ,
      fields:
        username: 1
        profile: 1

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
