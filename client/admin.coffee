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
  'click button.sync-arxiv-pdf-cache': (e) ->
    Meteor.call 'sync-arxiv-pdf-cache'
  'click button.sync-arxiv-metadata': (e) ->
    Meteor.call 'sync-arxiv-metadata'
  'click button.sync-local-pdf-cache': (e) ->
    Meteor.call 'sync-local-pdf-cache'
  'click button.process-pdfs': (e) ->
    Meteor.call 'process-pdfs'
  'click button.dummy-comments': (e) ->
    Meteor.call 'dummy-comments'
  'click button.dummy-annotations': (e) ->
    Meteor.call 'dummy-annotations'
