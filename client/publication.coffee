GetPublication = new Meteor.Collection 'get-publication'

do -> # To not pollute the namespace
  Meteor.autorun ->
    Meteor.subscribe 'get-publication', Session.get 'currentPublicationId'

  Template.publication.publication = ->
    JSON.stringify GetPublication.findOne()

