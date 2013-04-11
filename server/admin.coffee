do -> # To not pollute the namespace
  Meteor.publish 'arxiv-pdfs', ->
    ArXivPDFs.find()
