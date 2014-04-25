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
    libraryActive: false
    currentCollectionId: null
    currentCollectionSlug: null
    currentPublicationId: null
    currentPublicationSlug: null
    currentPublicationProgress: null
    currentHighlightId: null
    currentAnnotationId: null
    currentCommentId: null
    currentPersonSlug: null
    currentTagId: null
    currentTagSlug: null
    currentGroupId: null
    currentGroupSlug: null
    groupsActive: false
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
  # - annotationDefaults

  # Close sign in buttons dialog box when moving between pages
  Accounts._loginButtonsSession.closeDropdown()

notFound = ->
  # TODO: Is there a better/official way?
  Meteor.Router._page = 'notfound'
  Meteor.Router._pageDeps.changed()

redirectHighlightId = (highlightId) ->
  Meteor.call 'highlights-path', highlightId, (error, path) ->
    return notFound() if error or not path
    Meteor.Router.to Meteor.Router.highlightPath path...
  return # Return nothing

redirectAnnotationId = (annotationId) ->
  Meteor.call 'annotations-path', annotationId, (error, path) ->
    return notFound() if error or not path
    Meteor.Router.to Meteor.Router.annotationPath path...
  return # Return nothing

if INSTALL
  Meteor.Router.add
    '/': ->
      setSession()
      'install'

else
  # documentId can be a field or a function which maps from params. We
  # are using it in parsing HTML to extract all references. We extract
  # only those references for routes which have documentId set (and
  # have a place to store them in schema, eg. Annotation.references).

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
      documentId: 'highlightId'
      to: (publicationId, publicationSlug, highlightId) ->
        setSession
          currentPublicationId: publicationId
          currentPublicationSlug: publicationSlug
          currentHighlightId: highlightId
        'publication'

    '/p/:publicationId/:publicationSlug?/a/:annotationId':
      as: 'annotation'
      documentId: 'annotationId'
      to: (publicationId, publicationSlug, annotationId) ->
        setSession
          currentPublicationId: publicationId
          currentPublicationSlug: publicationSlug
          currentAnnotationId: annotationId
        'publication'

    '/p/:publicationId/:publicationSlug?/c/:commentId':
      as: 'comment'
      documentId: 'commentId'
      to: (publicationId, publicationSlug, commentId) ->
        setSession
          currentPublicationId: publicationId
          currentPublicationSlug: publicationSlug
          currentCommentId: commentId
        'publication'

    '/p/:publicationId/:publicationSlug?':
      as: 'publication'
      documentId: 'publicationId'
      to: (publicationId, publicationSlug) ->
        setSession
          currentPublicationId: publicationId
          currentPublicationSlug: publicationSlug
        'publication'

    '/t/:tagId/:tagSlug?':
      as: 'tag'
      documentId: 'tagId'
      to: (tagId, tagSlug) ->
        setSession
          currentTagId: tagId
          currentTagSlug: tagSlug
        'tag'

    '/g/:groupId/:groupSlug?':
      as: 'group'
      documentId: 'groupId'
      to: (groupId, groupSlug) ->
        setSession
          currentGroupId: groupId
          currentGroupSlug: groupSlug
        'group'

    '/g':
      as: 'groups'
      to: ->
        setSession
          groupsActive: true
        'groups'

    '/u/:personSlug':
      as: 'person'
      documentId: (params) ->
        return unless params.personSlug

        # No need for requireReadAccessSelector because persons are public
        Person.documents.findOne({slug: params.personSlug}, {fields: _id: 1})?._id
      to: (personSlug) ->
        setSession
          currentPersonSlug: personSlug
        'person'

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

    '/s/:searchQuery?':
      as: 'search'
      to: (searchQuery) ->
        # If search is already active, we don't reset other session variables, just update currentSearchQuery
        if Session.get 'searchActive'
          Session.set 'currentSearchQuery', searchQuery
        else
          setSession
            currentSearchQuery: searchQuery
            indexActive: true
            searchActive: true
        'index'

    '/c/:collectionId/:collectionSlug?':
      as: 'collection'
      to: (collectionId, collectionSlug) ->
        setSession
          currentCollectionId: collectionId
          currentCollectionSlug: collectionSlug
        'collection'

    '/admin':
      as: 'admin'
      to: ->
        setSession
          adminActive: true
        'admin'

    '/library':
      as: 'library'
      to: ->
        setSession
          libraryActive: true
        'library'

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
