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
    profile:
      name_first: $('#name_first').val()
      name_last: $('#name_last').val()
  , (err) ->
    if err
      Session.set 'error', err.reason
    else
      Meteor.Router.to '/'