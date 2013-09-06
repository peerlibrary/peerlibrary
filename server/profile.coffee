Accounts.onCreateUser (options, user) ->
  if not user.hasOwnProperty 'profile'
    id = Persons.insert
      user: user.username
    user.profile =
      person: id
  user

Meteor.publish 'users-by-username', (username) ->
  Meteor.users.find
    username: username
  ,
    fields:
      username: 1
      profile: 1

Meteor.publish 'persons-by-username', (username) ->
  Persons.find
    user: username
  ,
    fields:
      user: 1
      foreNames: 1
      lastName: 1
      work: 1
      education: 1
      publications: 1
