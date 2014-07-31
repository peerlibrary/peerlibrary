Deps.autorun ->
  if Session.equals 'adminActive', true
    Meteor.subscribe 'arxiv-pdfs'
    Meteor.subscribe 'logged-errors'
    Meteor.subscribe 'job-queue'

Template.adminCheck.isAdmin = ->
  Meteor.person(isAdmin: 1)?.isAdmin

Template.adminDevelopment.events
  'click button.sample-data': (event, template) ->
    Meteor.call 'sample-data', (error, result) ->
      Notify.smartError error if error

    return # Make sure CoffeeScript does not return anything

Template.adminPublications.events
  'click button.process-pdfs': (event, template) ->
    Meteor.call 'process-pdfs', (error, result) ->
      Notify.smartError error if error

    return # Make sure CoffeeScript does not return anything

Template.adminPublications.events
  'click button.reprocess-pdfs': (event, template) ->
    Meteor.call 'reprocess-pdfs', (error, result) ->
      Notify.smartError error if error

    return # Make sure CoffeeScript does not return anything

Template.adminDatabase.events
  'click button.update-all': (event, template) ->
    Meteor.call 'database-update-all', (error, result) ->
      Notify.smartError error if error

    return # Make sure CoffeeScript does not return anything

Template.adminErrors.events
  'click button.dummy-error': (event, template) ->
    # Throws a dummy error on button click, which should be logged
    # and stored in the database by our errors logging code
    throw new Error "Dummy error"

Template.adminErrors.errors = ->
  LoggedError.documents.find {}

Template.adminJobs.events
  'click button.test-job': (event, template) ->
    Meteor.call 'test-job', (error, result) ->
      Notify.meteorError error if error

    return # Make sure CoffeeScript does not return anything

Template.adminJobs.jobqueue = ->
  JobQueue.documents.find {},
    sort: [
      ['updated', 'desc']
    ]

Template.adminSources.events
  'click button.sync-local-pdf-cache': (event, template) ->
    Meteor.call 'sync-local-pdf-cache', (error, result) ->
      Notify.smartError error if error

    return # Make sure CoffeeScript does not return anything

Template.adminArXiv.events
  'click button.sync-arxiv-pdf-cache': (event, template) ->
    Meteor.call 'sync-arxiv-pdf-cache', (error, result) ->
      Notify.smartError error if error

    return # Make sure CoffeeScript does not return anything

  'click button.sync-arxiv-metadata': (event, template) ->
    Meteor.call 'sync-arxiv-metadata', (error, result) ->
      Notify.smartError error if error

    return # Make sure CoffeeScript does not return anything

Template.adminArXiv.PDFs = ->
  ArXivPDF.documents.find {},
    sort: [
      ['processingStart', 'desc']
    ]
    limit: 5

Template.adminFSM.events
  'click button.sync-fsm-cache': (event, template) ->
    Meteor.call 'sync-fsm-cache', (error, result) ->
      Notify.smartError error if error

    return # Make sure CoffeeScript does not return anything

  'click button.sync-fsm-metadata': (event, template) ->
    Meteor.call 'sync-fsm-metadata', (error, result) ->
      Notify.smartError error if error

    return # Make sure CoffeeScript does not return anything

Template.adminBlog.events
  'click button.sync-blog': (event, template) ->
    Meteor.call 'sync-blog', (error, result) ->
      Notify.smartError error if error

    return # Make sure CoffeeScript does not return anything
