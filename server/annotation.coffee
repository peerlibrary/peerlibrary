Meteor.publish 'annotations-by-publication', (publication) ->
  Annotations.find
    publication: publication
  ,
    sort:
      created: -1
