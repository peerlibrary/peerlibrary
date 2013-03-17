Meteor.startup ->
  Meteor.methods
    'server-time': -> (new Date).getTime()