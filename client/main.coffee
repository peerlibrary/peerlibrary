Meteor.Router.add
  '/': ->
    Session.set 'time', 123
    'hello'
  '/login': 'login'
  '/logout': ->
    Meteor.logout()
    'hello'
  '/register': 'register'
