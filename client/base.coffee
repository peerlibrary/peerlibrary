@INITIAL_SEARCH_LIMIT = INITIAL_SEARCH_LIMIT = 5

setSession = (session) ->
  session = _.defaults session,
    indexActive: false
    currentSearchQuery: null
    currentSearchQueryCountPublications: 0
    currentSearchQueryCountPersons: 0
    currentSearchQueryLoading: false
    currentSearchQueryReady: false
    currentSearchLimit: INITIAL_SEARCH_LIMIT
    searchActive: false
    searchFocused: false
    adminActive: false
    currentPublicationId: null
    currentPublicationSlug: null
    currentPublicationProgress: null
    currentPersonSlug: null

  for key, value of session
    Session.set key, value

  # Overlays are special and we do not clear them while routing

  # Close login buttons dialog box when moving between pages
  Accounts._loginButtonsSession.closeDropdown()

Meteor.Router.add
  '/':
    as: 'index'
    to: ->
      setSession
        indexActive: true
      'index'

  '/p/:publicationId/:publicationSlug?':
    as: 'publication'
    to: (publicationId, publicationSlug) ->
      setSession
        currentPublicationId: publicationId
        currentPublicationSlug: publicationSlug
      'publication'

  '/u/:personSlug':
    as: 'profile'
    to: (personSlug) ->
      setSession
        currentPersonSlug: personSlug
      'profile'

  '/about':
    as: 'about'
    to: ->
      setSession()
      'about'

  '/help':
    as: 'help'
    to: ->
      setSession()
      'help'

  '/privacy':
    as: 'privacy'
    to: ->
      setSession()
      'privacy'

  '/terms':
    as: 'terms'
    to: ->
      setSession()
      'terms'

  '/admin': ->
    as: 'admin'
    to: ->
      setSession
        adminActive: true
      'admin'

  '*': ->
    setSession()
    'notfound'

# TODO: Use real parser (arguments can be listed multiple times, arguments can be delimited by ";")
parseQuery = (qs) ->
  query = {}
  for pair in qs.replace('?', '').split '&'
    [k, v] = pair.split('=')
    query[k] = v
  query