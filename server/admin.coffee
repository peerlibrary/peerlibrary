do -> # To not pollute the namespace
  Meteor.publish 'arxiv-pdfs', ->
    ArXivPDFs.find {},
      sort:
        processingStart: -1
      limit: 5
