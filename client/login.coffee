Template.login.error = ->
  Session.get 'error'

Template.login.events =
  'submit': (e, template) ->
    e.preventDefault()
    handleLogin e
  'keypress input': (e, template) ->
    if e.which is 13
      e.preventDefault()
      handleLogin e

handleLogin = (e) ->
  Meteor.loginWithPassword $('#email').val(), $('#password').val(), (err) ->
    if err
      Session.set 'error', err.reason
    else
      Meteor.Router.to '/'