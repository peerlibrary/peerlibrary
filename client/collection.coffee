Deps.autorun ->
  if Session.get 'currentCollectionId'
    Meteor.subscribe 'collection-by-id', Session.get 'currentCollectionId'
    Meteor.subscribe 'collection-publications', Session.get 'currentCollectionId'

Deps.autorun ->
  collection = Collection.documents.findOne Session.get('currentCollectionId'),
    fields:
      _id: 1
      slug: 1

  return unless collection

  # currentCollectionSlug is null if slug is not present in location, so we use
  # null when collection.slug is empty string to prevent infinite looping
  return if Session.equals 'currentCollectionSlug', (collection.slug or null)

  Meteor.Router.toNew Meteor.Router.collectionPath collection._id, collection.slug

Template.collection.collection = ->
  Collection.documents.findOne Session.get('currentCollectionId')

Template.collectionPublications.publications = ->
  order = _.pluck @publications, '_id'

  Publication.documents.find
    _id:
      $in: order
  .fetch().sort (a,b) =>
    return (order.indexOf a._id) - (order.indexOf b._id)

Template.collectionPublications.rendered = ->
  $(@findAll '.collection-publications').sortable
    opacity: 0.5
    update: (event, ui) ->
      newOrder = []
      $(this).children("li").each () ->
        newOrder.push $(this).attr("data-id")

      Meteor.call "reorder-collection", Session.get('currentCollectionId'), newOrder, (error) ->
        return Notify.meteorError error, true if error

Template.collectionDetails.ownCollection = ->
  return unless Meteor.personId
  @author._id is Meteor.personId()

Template.collectionDetails.events
  'click .delete-collection': (e, template) ->

    Collection.documents.remove @_id, (error) =>
      Notify.meteorError error, true if error

      Notify.success "Collection removed."
      Meteor.Router.toNew Meteor.Router.libraryPath()

    return # Make sure CoffeeScript does not return anything
