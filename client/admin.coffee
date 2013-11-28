Deps.autorun ->
  if Session.equals 'adminActive', true
    Meteor.subscribe 'arxiv-pdfs'
    Meteor.subscribe 'errors'

Template.adminDevelopment.events
  'click button.sample-data': (e, template) ->
    # TODO
    return

Template.adminPublications.events
  'click button.sync-local-pdf-cache': (e, template) ->
    Meteor.call 'sync-local-pdf-cache'
  'click button.process-pdfs': (e, template) ->
    Meteor.call 'process-pdfs'

Template.adminErrors.events
  'click button.dummy-error': (e, template) ->
    # Throws a dummy error on button click, which should be logged
    # and stored in the database by our errors logging code
    throw new Error "Dummy error"

Template.adminErrors.errors = ->
  Errors.find {}

Template.adminArXiv.events
  'click button.sync-arxiv-pdf-cache': (e, template) ->
    Meteor.call 'sync-arxiv-pdf-cache'
  'click button.sync-arxiv-metadata': (e, template) ->
    Meteor.call 'sync-arxiv-metadata'

Template.adminArXiv.PDFs = ->
  ArXivPDFs.find {},
    sort: [
      ['processingStart', 'desc']
    ]
    limit: 5
