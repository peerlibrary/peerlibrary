do -> # To not pollute the namespace
  Meteor.publish 'user', (username) ->
    Meteor.users.find
      username: username
    , 
      fields:
        username: 1
        profile: 1