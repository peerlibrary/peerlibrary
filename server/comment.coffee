do -> # To not pollute the namespace
  Meteor.publish 'comments-by-publication-and-context', (publication, context) ->
    Comments.find
      publication: publication
      context: context
