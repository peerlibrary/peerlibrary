Meteor.publish 'notes-by-publication-and-paragraph', (publication, paragraph) ->
  Notes.find
    publication: publication
    paragraph: paragraph
  ,
    sort:
      created: -1
    limit: 1