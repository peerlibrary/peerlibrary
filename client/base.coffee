@INITIAL_SEARCH_LIMIT = INITIAL_SEARCH_LIMIT = 5

Meteor.Router.add
  '/': ->
    Session.set 'indexActive', true
    'index'

  '/login':
    'login'

  '/logout': ->
    Meteor.logout()
    # TODO: Redirect back to the page where it came from (or support logout without having to go to /logout)
    Meteor.Router.to '/'

  '/register':
    'register'

  '/p/:publicationId/:publicationSlug?':
    as: 'publication'
    to: (publicationId, publicationSlug) ->
      Session.set 'currentPublicationId', publicationId
      Session.set 'currentPublicationSlug', publicationSlug
      'publication'

  '/u/:personSlug':
    as: 'profile'
    to: (personSlug) ->
      Session.set 'currentPersonSlug', personSlug
      'profile'

  '/admin': ->
    Session.set 'adminActive', true
    'admin'

  '*':
    'notfound'

Meteor.Router.beforeRouting = ->
  Session.set 'indexActive', false
  Session.set 'indexHeader', $(window).scrollTop() < $(window).height()
  Session.set 'currentSearchQuery', null
  Session.set 'currentSearchQueryCountPublications', 0
  Session.set 'currentSearchQueryCountPeople', 0
  Session.set 'currentSearchQueryLoading', false
  Session.set 'currentSearchQueryReady', false
  Session.set 'currentSearchLimit', INITIAL_SEARCH_LIMIT
  Session.set 'searchActive', false
  Session.set 'searchFocused', false
  Session.set 'adminActive', false
  Session.set 'currentPublicationId', null
  Session.set 'currentPublicationSlug', null
  Session.set 'currentPersonSlug', null

# TODO: Use real parser (arguments can be listed multiple times, arguments can be delimited by ";")
parseQuery = (qs) ->
  query = {}
  for pair in qs.replace('?', '').split '&'
    [k, v] = pair.split('=')
    query[k] = v
  query