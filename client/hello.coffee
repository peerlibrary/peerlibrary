Template.hello.person = ->
  Meteor.userId()

Template.hello.time = ->
  Session.get 'time'

Template.hello.events =
  'click input': ->
    loadTime()

loadTime = ->
  Meteor.call 'server-time', (err, time) ->
    Session.set 'time', time