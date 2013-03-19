do -> # To not pollute the namespace
  Meteor.Router.add
    '/': ->
      Session.set 'time', 123
      'index'
    '/login': 'login'
    '/logout': ->
      Meteor.logout()
      'hello'
    '/register': 'register'
    '/p/:publicationId': (publicationId) ->
      Session.set 'currentPublicationId', publicationId
      'publication'
    '/u/:username': (username) ->
      Session.set 'currentProfileUsername', username
      'profile'
