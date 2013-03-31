do -> # To not pollute the namespace
  Meteor.publish 'users', (username) ->
    Meteor.users.find
      username: username
    , 
      fields:
        username: 1
        profile: 1