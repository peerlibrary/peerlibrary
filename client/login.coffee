do -> # To not pollute the namespace
  Template.login.error = ->
    Session.get 'error'

  Template.login.events =
    'submit': (e) ->
      e.preventDefault()
      handleLogin e
    'keypress input': (e) ->
      if e.which is 13
        e.preventDefault()
        handleLogin e

  handleLogin = (e) ->
    Meteor.loginWithPassword $('#email').val(), $('#password').val(), (err) ->
      if err
        Session.set 'error', err.reason
      else
        Meteor.Router.to '/'