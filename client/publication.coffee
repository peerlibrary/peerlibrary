GetPublication = new Meteor.Collection 'get-publication'

class Publication extends Document
  createdDay = ->
    moment(@created).format('MMMM Do YYYY')

do -> # To not pollute the namespace
  Meteor.startup ->
    Meteor.autorun ->
      Session.set 'getPublicationError', undefined
      Meteor.subscribe 'get-publication', Session.get('currentPublicationId'), {
        onError: (error) ->
          # TODO: Currently, error.reason is always empty, a Meteor bug?
          Session.set 'getPublicationError', error.reason ? "Unknown error"
      }

  Template.publication.publication = ->
    GetPublication.findOne()

  Template.publication.publicationError = ->
    Session.get 'getPublicationError'

  Template.publicationItem.displayDay = (time) ->
      moment(time).format('MMMM Do YYYY')