@INITIAL_SEARCH_LIMIT = 5
@INITIAL_CATALOG_LIMIT = 10

setSession = (session) ->
  session = _.defaults session or {},
    # TODO: All these variables should be encoded in the URL somehow, or they should not be reset when routing (use Session.setDefault; we are using it already, we should put all together; or should we use independent reactive variables instead of Session for such variables?)
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
    publicationJobsId: null
    libraryActive: false
    settingsActive: false
    userNotificationsActive: false
    currentCollectionId: null
    currentCollectionSlug: null
    currentPublicationId: null
    currentPublicationSlug: null
    currentPublicationProgress: null # TODO: This does not have to be a session variable, but just a normal reactive variable
    currentPublicationLimitAnnotationsToViewport: false
    currentHighlightId: null
    currentAnnotationId: null
    currentCommentId: null
    currentPersonSlug: null
    currentTagId: null
    currentTagSlug: null
    currentGroupId: null
    currentGroupSlug: null
    publicationsActive: false
    currentPublicationsFilter: null
    currentPublicationsCount: 0
    currentPublicationsLoading: false
    currentPublicationsReady: false
    currentPublicationsLimit: INITIAL_CATALOG_LIMIT
    currentPublicationsLimitIncreasing: false
    currentPublicationsSort: 0
    personsActive: false
    currentPersonsFilter: null
    currentPersonsCount: 0
    currentPersonsLoading: false
    currentPersonsReady: false
    currentPersonsLimit: INITIAL_CATALOG_LIMIT
    currentPersonsLimitIncreasing: false
    currentPersonsSort: 0
    collectionsActive: false
    currentCollectionsFilter: null
    currentCollectionsCount: 0
    currentCollectionsLoading: false
    currentCollectionsReady: false
    currentCollectionsLimit: INITIAL_CATALOG_LIMIT
    currentCollectionsLimitIncreasing: false
    currentCollectionsSort: 0
    groupsActive: false
    currentGroupsFilter: null
    currentGroupsCount: 0
    currentGroupsLoading: false
    currentGroupsReady: false
    currentGroupsLimit: INITIAL_CATALOG_LIMIT
    currentGroupsLimitIncreasing: false
    currentGroupsSort: 0
    annotationsActive: false
    currentAnnotationsFilter: null
    currentAnnotationsCount: 0
    currentAnnotationsLoading: false
    currentAnnotationsReady: false
    currentAnnotationsLimit: INITIAL_CATALOG_LIMIT
    currentAnnotationsLimitIncreasing: false
    currentAnnotationsSort: 0
    highlightsActive: false
    currentHighlightsFilter: null
    currentHighlightsCount: 0
    currentHighlightsLoading: false
    currentHighlightsReady: false
    currentHighlightsLimit: INITIAL_CATALOG_LIMIT
    currentHighlightsLimitIncreasing: false
    currentHighlightsSort: 0
    inviteDialogActive: false
    inviteDialogSubscribing: false
    inviteDialogError: null
    newsletterDialogActive: false
    newsletterDialogSubscribing: false
    newsletterDialogError: null
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
  Meteor.Router._page = 'notFound'
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

redirectCommentId = (commentId) ->
  Meteor.call 'comments-path', commentId, (error, path) ->
    return notFound() if error or not path
    Meteor.Router.to Meteor.Router.commentPath path...
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
  # With documentName you can override the name of a reference
  # (otherwise route name is used).

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

    '/accept-invitation/:enrollAccountToken':
      to: (enrollAccountToken) ->
        # Make sure nobody is logged in, it would be confusing otherwise
        # TODO: How to make it sure we do not log in in the first place? How could we set autoLoginEnabled in time? Because this logs out user in all tabs
        Meteor.logout()
        setSession
          indexActive: true
          enrollAccountToken: enrollAccountToken
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

    '/p/:publicationId/:publicationSlug?/m/:commentId':
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

    '/p':
      as: 'publications'
      to: ->
        setSession
          publicationsActive: true
        'publications'

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
        try
          check params.personSlug, NonEmptyString
        catch error
          # Not a valid document ID or slug
          return

        person = Person.documents.findOne
          $or: [
            slug: params.personSlug
          ,
            _id: params.personSlug
          ]
        ,
          fields:
            _id: 1

        return person._id if person

        # A special case for the client side, we return slug as an ID which is then passed to personPathFromId
        params.personSlug if Meteor.isClient
      to: (personSlug) ->
        setSession
          currentPersonSlug: personSlug
        'person'

    '/u':
      as: 'persons'
      to: ->
        setSession
          personsActive: true
        'persons'

    '/h/:highlightId':
      as: 'highlightId'
      documentId: 'highlightId'
      documentName: 'highlight'
      to: (highlightId) ->
        setSession()
        redirectHighlightId highlightId
        'redirecting'

    '/h':
      as: 'highlights'
      to: ->
        setSession
          highlightsActive: true
        'highlights'

    '/a/:annotationId':
      as: 'annotationId'
      documentId: 'annotationId'
      documentName: 'annotation'
      to: (annotationId) ->
        setSession()
        redirectAnnotationId annotationId
        'redirecting'

    '/a':
      as: 'annotations'
      to: ->
        setSession
          annotationsActive: true
        'annotations'

    '/m/:commentId':
      as: 'commentId'
      documentId: 'commentId'
      documentName: 'comment'
      to: (commentId) ->
        setSession()
        redirectCommentId commentId
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
      documentId: 'collectionId'
      to: (collectionId, collectionSlug) ->
        setSession
          currentCollectionId: collectionId
          currentCollectionSlug: collectionSlug
        'collection'

    '/c':
      as: 'collections'
      to: ->
        setSession
          collectionsActive: true
        'collections'

    '/admin':
      as: 'admin'
      to: ->
        setSession
          adminActive: true
        'admin'

    '/admin/jobs/p/:publicationId':
      as: 'publicationJobs'
      to: (publicationId) ->
        setSession
          publicationJobsId: publicationId
        'publicationJobs'

    '/library':
      as: 'library'
      to: ->
        setSession
          libraryActive: true
        'library'

    '/settings':
      as: 'settings'
      to: ->
        setSession
          settingsActive: true
        'settings'

    '/notifications':
      as: 'userNotifications'
      to: ->
        setSession
          userNotificationsActive: true
        'userNotifications'

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
    'notFound'
