do -> # To not pollute the namespace
  Meteor.publish 'get-profile', (username) ->
    Meteor.users.find
      username: username