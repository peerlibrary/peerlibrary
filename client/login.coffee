Template.login.error = ->
  Session.get 'error'

Template.login.events =
  'submit': (e) ->
    e.preventDefault()
    Meteor.loginWithPassword $('#email').val(), $('#password').val(), (err) ->
      if err
        Session.set 'error', err.reason
      else
        Meteor.Router.to '/'