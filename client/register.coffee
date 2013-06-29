Template.register.error = ->
  Session.get 'error'

Template.register.events =
  'submit': (e) ->
    e.preventDefault()
    handleRegister e
  'keypress input': (e) ->
    if e.which is 13
      e.preventDefault()
      handleRegister e

handleRegister = (e) ->
  Accounts.createUser
    email: $('#email').val()
    password: $('#password').val()
    #TODO: handle username conflicts
    username: $('#firstName').val().toLowerCase() + '-' + $('#lastName').val().toLowerCase()
    profile:
      firstName: $('#firstName').val()
      lastName: $('#lastName').val()
  , (err) ->
    if err
      Session.set 'error', err.reason
    else
      Meteor.Router.to '/'
