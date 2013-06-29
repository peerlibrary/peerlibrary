Meteor.publish 'arxiv-pdfs', ->
  ArXivPDFs.find {},
    sort:
      processingStart: -1
    limit: 5
