Deps.autorun ->
  if Session.equals 'adminActive', true
    Meteor.subscribe 'arxiv-pdfs'

Template.admin.arXivPDFs = ->
  ArXivPDFs.find {},
    sort: [
      ['processingStart', 'desc']
    ]
    limit: 5

Template.adminButtons.events
  'click button.sync-arxiv-pdf-cache': (e, template) ->
    Meteor.call 'sync-arxiv-pdf-cache'
    return # Make sure CoffeeScript does not return anything

  'click button.sync-arxiv-metadata': (e, template) ->
    Meteor.call 'sync-arxiv-metadata'
    return # Make sure CoffeeScript does not return anything

  'click button.sync-local-pdf-cache': (e, template) ->
    Meteor.call 'sync-local-pdf-cache'
    return # Make sure CoffeeScript does not return anything

  'click button.process-pdfs': (e, template) ->
    Meteor.call 'process-pdfs'
    return # Make sure CoffeeScript does not return anything
