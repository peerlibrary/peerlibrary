Accounts.onCreateUser (options, user) ->
  if user.hasOwnProperty 'person'
    id = Persons.insert
      user: user.username
    user.person = id
    user

Meteor.publish 'users-by-username', (username) ->
  Meteor.users.find
    username: username
  ,
    fields:
      username: 1
      person: 1

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
