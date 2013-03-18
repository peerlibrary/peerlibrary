Meteor.Router.add
  '/': ->
    Session.set 'time', 123
    'index'
  '/login': 'login'
  '/logout': ->
    Meteor.logout()
    'hello'
  '/register': 'register'
