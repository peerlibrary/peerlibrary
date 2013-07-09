Meteor.publish 'arxiv-pdfs', ->
  ArXivPDFs.find {},
    sort: [
      ['processingStart', 'desc']
    ]
    limit: 5
