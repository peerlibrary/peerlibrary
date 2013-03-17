Template.register.error = ->
  Session.get 'error'

Template.register.events =
  'submit': (e) ->
    e.preventDefault()
    Accounts.createUser
      username: $('#username').val()
      email: $('#email').val()
      password: $('#password').val()
    , (err) ->
      if err
        Session.set 'error', err.reason
      else
        Meteor.Router.to '/'