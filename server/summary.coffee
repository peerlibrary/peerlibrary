do -> # To not pollute the namespace
  Meteor.publish 'summaries-by-publication-and-paragraph', (publication, paragraph) ->
    Summaries.find
      publication: publication
      context: paragraph
    ,
      sort:
        created: -1
      limit: 1