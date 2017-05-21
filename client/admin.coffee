Deps.autorun ->
  if Session.equals 'adminSources', true
    Meteor.subscribe 'arxiv-pdfs'
  
  if Session.equals 'adminJobs', true
    Meteor.subscribe 'job-queue'

  if Session.equals 'adminErrors', true
    Meteor.subscribe 'logged-errors'

Template.adminCheck.isAdmin = ->
  Meteor.person(isAdmin: 1)?.isAdmin

Template.adminDevelopment.events
  'click button.sample-data': (event, template) ->
    Meteor.call 'sample-data', (error, result) ->
      FlashMessage.fromError error if error

    return # Make sure CoffeeScript does not return anything

Template.adminPublications.events
  'click button.process-pdfs': (event, template) ->
    Meteor.call 'process-pdfs', (error, result) ->
      FlashMessage.fromError error if error

    return # Make sure CoffeeScript does not return anything

Template.adminPublications.events
  'click button.reprocess-pdfs': (event, template) ->
    Meteor.call 'reprocess-pdfs', (error, result) ->
      FlashMessage.fromError error if error

    return # Make sure CoffeeScript does not return anything

Template.adminDatabase.events
  'click button.update-all': (event, template) ->
    Meteor.call 'database-update-all', (error, result) ->
      FlashMessage.fromError error if error

    return # Make sure CoffeeScript does not return anything

Template.adminErrors.events
  'click button.dummy-error': (event, template) ->
    # Throws a dummy error on button click, which should be logged
    # and stored in the database by our errors logging code
    throw new Error "Dummy error"

Template.adminErrors.errors = ->
  LoggedError.documents.find {},
    sort: [
      ['serverTime', 'desc']
    ]

Template.adminErrors.catalogSettings = -> 
  subscription: 'logged-errors'
  documentClass: LoggedError
  variables: 
    active: 'adminErrors'
    ready: 'currentAdminErrorsReady'
    loading: 'currentAdminErrorsLoading'
    count: 'currentAdminErrorsCount'
    filter: 'currentAdminErrorsFilter'
    limit: 'currentAdminErrorsLimit'
    limitIncreasing: 'currentAdminErrorsLimitIncreasing'
    sort: 'currentAdminErrorsSort'

EnableCatalogItemLink Template.adminErrorsCatalogItem

Template.adminJobs.catalogSettings = -> 
  subscription: 'job-queue'
  documentClass: JobQueue
  variables: 
    active: 'adminJobs'
    ready: 'currentAdminJobsReady'
    loading: 'currentAdminJobsLoading'
    count: 'currentAdminJobsCount'
    filter: 'currentAdminJobsFilter'
    limit: 'currentAdminJobsLimit'
    limitIncreasing: 'currentAdminJobsLimitIncreasing'
    sort: 'currentAdminJobsSort'

EnableCatalogItemLink Template.adminJobQueueItem

Template.adminJobs.events
  'click button.test-job': (event, template) ->
    Meteor.call 'test-job', (error, result) ->
      FlashMessage.fromError error if error

    return # Make sure CoffeeScript does not return anything

Template.adminJobs.jobqueue = ->
  JobQueue.documents.find {},
    sort: [
      ['updated', 'desc']
    ]
    transform: null # So that publication subdocument does not get client-only attributes like _pages and _highlighter

Template.adminJobQueueItem.canManageJob = ->
  person = Meteor.person _.extend Publication.maintainerAccessPersonFields(),
    isAdmin: 1

  return false unless person

  return true if person.isAdmin

  if @data.publication
    # We have to refresh manually the publication because data.publication is
    # not an instance of Publication because we disable transform in the
    # publicationJobs template to display data payload without client-only
    # attributes like _pages and _highlighter.
    publication = Publication.documents.findOne @data.publication._id, fields: Publication.maintainerAccessSelfFields()
    # When used on the generic job queue page where we are not subscribed
    # to all publications, publication will probably not be found, but this
    # is probably OK because we are currently not showing anything on the
    # generic job queue page to non-admins anyway.
    return publication?.hasMaintainerAccess person

Template.adminJobQueueItem.isRestartable = ->
  @status in JobQueue.Meta.collection.jobStatusRestartable

Template.adminJobQueueItem.isCancellable = ->
  @status in JobQueue.Meta.collection.jobStatusCancellable

Template.adminJobQueueItem.inFuture = ->
  @after and @after > moment.utc().toDate()

Template.adminJobQueueItem.events
  'click .admin-job-cancel': (event, template) ->
    event.preventDefault()

    Meteor.call 'admin-job-cancel', @_id, @runId, (error, result) ->
      FlashMessage.fromError error if error

    return # Make sure CoffeeScript does not return anything

  'click .admin-job-restart': (event, template) ->
    event.preventDefault()

    Meteor.call 'admin-job-restart', @_id, @runId, (error, result) ->
      FlashMessage.fromError error if error

    return # Make sure CoffeeScript does not return anything

Template.adminSources.events
  'click button.sync-local-pdf-cache': (event, template) ->
    Meteor.call 'sync-local-pdf-cache', (error, result) ->
      FlashMessage.fromError error if error

    return # Make sure CoffeeScript does not return anything

Template.adminArXiv.events
  'click button.sync-arxiv-pdf-cache': (event, template) ->
    Meteor.call 'sync-arxiv-pdf-cache', (error, result) ->
      FlashMessage.fromError error if error

    return # Make sure CoffeeScript does not return anything

  'click button.sync-arxiv-metadata': (event, template) ->
    Meteor.call 'sync-arxiv-metadata', (error, result) ->
      FlashMessage.fromError error if error

    return # Make sure CoffeeScript does not return anything

Template.adminFSM.events
  'click button.sync-fsm-metadata': (event, template) ->
    Meteor.call 'sync-fsm-metadata', (error, result) ->
      FlashMessage.fromError error if error

    return # Make sure CoffeeScript does not return anything

Template.adminBlog.events
  'click button.sync-blog': (event, template) ->
    Meteor.call 'sync-blog', (error, result) ->
      FlashMessage.fromError error if error

    return # Make sure CoffeeScript does not return anything
