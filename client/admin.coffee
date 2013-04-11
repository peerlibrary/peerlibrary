do -> # To not pollute the namespace
  Template.admin.arXivPDFs = ->
    ArXivPDFs.find()

  Template.arXivRefresh.events
    'click button': (e) ->
      Meteor.call 'refresh-arxhiv-pdfs'
