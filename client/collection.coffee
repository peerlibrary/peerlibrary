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
  # TODO: Change to MongoDB sort once/if they implement sort by array, https://jira.mongodb.org/browse/SERVER-7528
  .fetch().sort (a, b) =>
    return (order.indexOf a._id) - (order.indexOf b._id)

Template.collectionPublications.rendered = ->
  collection = Collection.documents.findOne Session.get('currentCollectionId')

  # Do not proceed if user is not collection author
  if collection?.author._id isnt Meteor.personId()
    # Remove sortable functionality in case it was previously enabled
    $(@findAll '.collection-publications.ui-sortable').sortable "destroy"
    return

  $(@findAll '.collection-publications').sortable
    opacity: 0.5
    cursor: 'ns-resize'
    axis: 'y'
    update: (e, ui) ->
      newOrder = []
      $(e.target).children('li').each (index, element) ->
        newOrder.push $(element).data('publication-id')

      Meteor.call 'reorder-collection', Session.get('currentCollectionId'), newOrder, (error) ->
        return Notify.meteorError error, true if error

Template.collectionDetails.ownCollection = ->
  return unless Meteor.personId()
  @author._id is Meteor.personId()

Template.collectionDetails.events
  'click .delete-collection': (e, template) ->
    Meteor.call 'remove-collection', @_id, (error, count) =>
      Notify.meteorError error, true if error

      return unless count

      Notify.success "Collection removed."
      # TODO: Consider redirecting back to the page where we came from (maybe /c, maybe /library)
      Meteor.Router.toNew Meteor.Router.libraryPath()

    return # Make sure CoffeeScript does not return anything

# This provides functionality of the library menu (from publication.html) that is specific to the collection view
Template.publicationLibraryMenuButtons.inCurrentCollection = ->
  Collection.documents.findOne
    _id: Session.get 'currentCollectionId'
    'publications._id': @_id

Template.publicationLibraryMenuButtons.events
  'click .remove-from-current-collection': (e, template) ->
    person = Meteor.person()
    return unless person

    collection = Collection.documents.findOne
      _id: Session.get 'currentCollectionId'
      'publications._id': @_id

    return unless collection

    Meteor.call 'remove-from-library', @_id, collection._id, (error, count) =>
      return Notify.meteorError error, true if error

      Notify.success "Publication removed from the collection." if count

    return # Make sure CoffeeScript does not return anything

