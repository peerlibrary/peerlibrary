Template.hello.person = ->
    'rodrigo'

Template.hello.time = ->
    Session.get 'time'

Template.hello.events =
    'click input': ->
      loadTime()

Meteor.Router.add
  '/': ->
    Session.set 'time', 123
    'hello'

loadTime = ->
  Meteor.call 'server-time', (err, time) ->
    Session.set 'time', time