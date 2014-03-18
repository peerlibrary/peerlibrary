@INITIAL_SEARCH_LIMIT = INITIAL_SEARCH_LIMIT = 5

setSession = (session) ->
  session = _.defaults session or {},
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
    currentHighlightId: null
    currentAnnotationId: null
    currentPersonSlug: null
    currentTagId: null
    currentTagSlug: null
    newsletterActive: false
    newsletterSubscribing: false
    newsletterError: null
    installInProgress: false
    installRestarting: false
    installError: null
    resetPasswordToken: null
    enrollAccountToken: null
    justVerifiedEmail: false

  for key, value of session
    if key in ['resetPasswordToken', 'enrollAccountToken', 'justVerifiedEmail']
      Accounts._loginButtonsSession.set key, value
    else
      Session.set key, value

  # Those are special and we do not clear them while routing.
  # Care has to be taken that they are set and unset manually.
  # - importOverlayActive
  # - signInOverlayActive

  # Close sign in buttons dialog box when moving between pages
  Accounts._loginButtonsSession.closeDropdown()

notFound = ->
  # TODO: Is there a better/official way?
  Meteor.Router._page = 'notfound'
  Meteor.Router._pageDeps.changed()

# TODO: We could just use a method here?
redirectHighlightId = (highlightId) ->
  highlightsHandle = Meteor.subscribe 'highlights-by-id', highlightId,
    onError: (error) ->
      notFound()
    onReady: ->
      highlight = Highlight.documents.findOne highlightId

      unless highlight
        highlightsHandle.stop()
        notFound()
        return

      publicationsHandle = Meteor.subscribe 'publications-by-id', highlight.publication._id,
        onError: (error) ->
          highlightsHandle.stop()
          notFound()
        onReady: ->
          publication = Publication.documents.findOne highlight.publication._id

          # We do not need subscriptions anymore
          highlightsHandle.stop()
          publicationsHandle.stop()

          unless publication
            notFound()
            return

          Meteor.Router.to  Meteor.Router.highlightPath publication._id, publication.slug, highlightId

  return # Return nothing

# TODO: We could just use a method here?
redirectAnnotationId = (annotationId) ->
  annotationsHandle = Meteor.subscribe 'annotations-by-id', annotationId,
    onError: (error) ->
      notFound()
    onReady: ->
      annotation = LocalAnnotation.documents.findOne annotationId

      unless annotation
        annotationsHandle.stop()
        notFound()
        return

      publicationsHandle = Meteor.subscribe 'publications-by-id', annotation.publication._id,
        onError: (error) ->
          annotationsHandle.stop()
          notFound()
        onReady: ->
          publication = Publication.documents.findOne annotation.publication._id

          # We do not need subscriptions anymore
          annotationsHandle.stop()
          publicationsHandle.stop()

          unless publication
            notFound()
            return

          Meteor.Router.to  Meteor.Router.annotationPath publication._id, publication.slug, annotationId

  return # Return nothing

if INSTALL
  Meteor.Router.add
    '/': ->
      setSession()
      'install'

else
  Meteor.Router.add
    '/':
      as: 'index'
      to: ->
        setSession
          indexActive: true
        'index'

    '/reset-password/:resetPasswordToken':
      to: (resetPasswordToken) ->
        # Make sure nobody is logged in, it would be confusing otherwise
        # TODO: How to make it sure we do not log in in the first place? How could we set autoLoginEnabled in time? Because this logs out user in all tabs
        Meteor.logout()
        setSession
          indexActive: true
          resetPasswordToken: resetPasswordToken
        'index'

    '/p/:publicationId/:publicationSlug?/h/:highlightId':
      as: 'highlight'
      to: (publicationId, publicationSlug, highlightId) ->
        setSession
          currentPublicationId: publicationId
          currentPublicationSlug: publicationSlug
          currentHighlightId: highlightId
        'publication'

    '/p/:publicationId/:publicationSlug?/a/:annotationId':
      as: 'annotation'
      to: (publicationId, publicationSlug, annotationId) ->
        setSession
          currentPublicationId: publicationId
          currentPublicationSlug: publicationSlug
          currentAnnotationId: annotationId
        'publication'

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

    '/h/:highlightId':
      as: 'highlightId'
      to: (highlightId) ->
        setSession()
        redirectHighlightId highlightId
        'redirecting'

    '/a/:annotationId':
      as: 'annotationId'
      to: (annotationId) ->
        setSession()
        redirectAnnotationId annotationId
        'redirecting'

    '/t/:tagId/:tagSlug?':
      as: 'tag'
      to: (tagId, tagSlug) ->
        setSession
          currentTagId: tagId
          currentTagSlug: tagSlug
        'tag'

    '/admin':
      as: 'admin'
      to: ->
        setSession
          adminActive: true
        'admin'

Meteor.Router.add
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
