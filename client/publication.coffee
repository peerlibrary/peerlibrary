do -> # To not pollute the namespace
  Deps.autorun ->
    Meteor.subscribe 'publications-by-id', Session.get 'currentPublicationId'

  Template.publication.publication = ->
    Publications.findOne Session.get 'currentPublicationId'

  Template.publicationItem.displayDay = (time) ->
      moment(time).format 'MMMM Do YYYY'
