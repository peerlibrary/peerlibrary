do -> # To not pollute the namespace
  Template.admin.arXivPDFs = ->
    ArXivPDFs.find()

  Template.arXivRefresh.events
    'click button.arxiv-pdfs': (e) ->
      Meteor.call 'refresh-arxhiv-pdfs'
    'click button.arxiv-meta': (e) ->
      Meteor.call 'refresh-arxhiv-meta'
    'click button.pdfs-cache': (e) ->
      Meteor.call 'refresh-pdfs-cache'
    'click button.process-pdfs': (e) ->
      Meteor.call 'process-pdfs'
    'click button.dummy-comments': (e) ->
      Meteor.call 'dummy-comments'
