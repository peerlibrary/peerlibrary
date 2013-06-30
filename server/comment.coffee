Meteor.publish 'comments-by-publication', (publication) ->
  Comments.find
    publication: publication
