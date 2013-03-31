class Publication extends Publication
  # TODO: Move to lib? Can be also on the server side, no?
  createdDay = =>
    moment(@created).format 'MMMM Do YYYY'

do -> # To not pollute the namespace
  Deps.autorun ->
    Meteor.subscribe 'publications-by-id', Session.get 'currentPublicationId'

  Template.publication.publication = ->
    Publications.findOne Session.get 'currentPublicationId'

  Template.publicationItem.displayDay = (time) ->
      moment(time).format 'MMMM Do YYYY'
