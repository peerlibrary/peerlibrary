do -> # To not pollute the namespace
  Meteor.startup ->
    Meteor.methods
      'server-time': -> (new Date).getTime()
