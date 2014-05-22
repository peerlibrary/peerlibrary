collectionHandle = null

# Mostly used just to force reevaluation of collectionHandle
collectionSubscribing = new Variable false

Deps.autorun ->
  if Session.get 'currentCollectionId'
    collectionSubscribing.set true
    collectionHandle = Meteor.subscribe 'collection-by-id', Session.get 'currentCollectionId'
    Meteor.subscribe 'publications-by-collection', Session.get 'currentCollectionId'
  else
    collectionSubscribing.set false
    collectionHandle = null

Deps.autorun ->
  if collectionSubscribing() and collectionHandle?.ready()
    collectionSubscribing.set false

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

Template.collection.loading = ->
  collectionSubscribing() # To register dependency
  not collectionHandle?.ready()

Template.collection.notFound = ->
  collectionSubscribing() # To register dependency
  collectionHandle?.ready() and not Collection.documents.findOne Session.get('currentCollectionId'), fields: _id: 1

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

  # Do not proceed if user cannot modify a collection
  # TODO: Can we make this reactive? So that if permissions change this is enabled or disabled?
  unless collection?.hasMaintainerAccess Meteor.person()
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

Template.collectionDetails.canModify = ->
  @hasMaintainerAccess Meteor.person()

Template.collectionDetails.canRemove = ->
  @hasRemoveAccess Meteor.person()

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

# We allow passing the collection slug if caller knows it
Handlebars.registerHelper 'collectionPathFromId', (collectionId, slug, options) ->
  collection = Collection.documents.findOne collectionId

  return Meteor.Router.collectionPath collection._id, collection.slug if collection

  Meteor.Router.collectionPath collectionId, slug

# Optional collection document
Handlebars.registerHelper 'collectionReference', (collectionId, collection, options) ->
  collection = Collection.documents.findOne collectionId unless collection
  assert collectionId, comment._id if collection

  _id: collectionId # TODO: Remove when we will be able to access parent template context
  text: "c:#{ collectionId }"
  title: collection?.name or collection?.slug

Editable.template Template.collectionCatalogItemName, ->
  @data.hasMaintainerAccess Meteor.person()
,
(name) ->
  Meteor.call 'collection-set-name', @data._id, name, (error, count) ->
    return Notify.meteorError error, true if error
,
  "Enter collection name"
,
  true

Template.collectionName[method] = Template.collectionCatalogItemName[method] for method in ['created', 'rendered', 'destroyed']

Template.collectionCatalogItem.countDescription = ->
  if @publications?.length is 1 then "1 publication" else "#{ @publications?.length or 0 } publications"
