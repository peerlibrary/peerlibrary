Template.register.error = ->
  Session.get 'error'

Template.register.events =
  'submit': (e) ->
    e.preventDefault()
    handleRegister e
  'keydown': (e) ->
    if e.which == 13
      e.preventDefault()
      handleRegister e

handleRegister = (e) ->
  Accounts.createUser
    email: $('#email').val()
    password: $('#password').val()
  , (err) ->
    if err
      Session.set 'error', err.reason
    else
      Meteor.Router.to '/'