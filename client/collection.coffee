class @Collection extends Collection
  @Meta
    name: 'Collection'
    replaceParent: true

  # We allow passing the collection slug if caller knows it
  @pathFromId: (collectionId, slug) ->
    assert _.isString collectionId

    collection = @documents.findOne collectionId

    return Meteor.Router.collectionPath collection._id, (collection.slug ? slug) if collection

    Meteor.Router.collectionPath collectionId, slug

  path: =>
    @constructor.pathFromId @_id, @slug

  route: =>
    source: @constructor.verboseName()
    route: 'collection'
    params:
      collectionId: @_id
      collectionSlug: @slug

  # Helper object with properties useful to refer to this document. Optional group document.
  @reference: (collectionId, collection) ->
    assert _.isString collectionId

    collection = @documents.findOne collectionId unless collection
    assert collectionId, collection._id if collection

    _id: collectionId # TODO: Remove when we will be able to access parent template context
    text: "c:#{ collectionId }"
    title: collection?.name or collection?.slug

  reference: =>
    @constructor.reference @_id, @

collectionHandle = null

# Mostly used just to force reevaluation of collectionHandle
collectionSubscribing = new Variable false

Tracker.autorun ->
  if Session.get 'currentCollectionId'
    collectionSubscribing.set true
    collectionHandle = Meteor.subscribe 'collection-by-id', Session.get 'currentCollectionId'
    Meteor.subscribe 'publications-by-collection', Session.get 'currentCollectionId'
  else
    collectionSubscribing.set false
    collectionHandle = null

Tracker.autorun ->
  if collectionSubscribing() and collectionHandle?.ready()
    collectionSubscribing.set false

Tracker.autorun ->
  collection = Collection.documents.findOne Session.get('currentCollectionId'),
    fields:
      _id: 1
      slug: 1

  return unless collection

  # currentCollectionSlug is null if slug is not present in location, so we use
  # null when collection.slug is empty string to prevent infinite looping
  return if Session.equals 'currentCollectionSlug', (collection.slug or null)

  Meteor.Router.toNew Meteor.Router.collectionPath collection._id, collection.slug

Template.collection.helpers
  loading: ->
    collectionSubscribing() # To register dependency
    not collectionHandle?.ready()

  notFound: ->
    collectionSubscribing() # To register dependency
    collectionHandle?.ready() and not Collection.documents.findOne Session.get('currentCollectionId'), fields: _id: 1

  collection: ->
    Collection.documents.findOne Session.get('currentCollectionId')

Editable.template Template.collectionName, ->
  @data.hasMaintainerAccess Meteor.person @data.constructor.maintainerAccessPersonFields()
,
  (name) ->
    Meteor.call 'collection-set-name', @data._id, name, (error, count) ->
      return FlashMessage.fromError error, true if error
,
  "Enter collection name"
,
  true

Template.collectionPublications.helpers
  publications: ->
    return unless @_id

    order = _.pluck @publications, '_id'

    Publication.documents.find(
      _id:
        $in: order
    # TODO: Change to MongoDB sort once/if they implement sort by array, https://jira.mongodb.org/browse/SERVER-7528
    ).fetch().sort (a, b) =>
      return (order.indexOf a._id) - (order.indexOf b._id)

Template.collectionPublications.rendered = ->
  collection = Collection.documents.findOne Session.get('currentCollectionId')

  # Do not proceed if user cannot modify a collection
  # TODO: Can we make this reactive? So that if permissions change this is enabled or disabled?
  unless collection?.hasMaintainerAccess Meteor.person collection?.constructor.maintainerAccessPersonFields()
    # Remove sortable functionality in case it was previously enabled
    @$('.collection-publications.ui-sortable').sortable "destroy"
    return

  @$('.collection-publications').sortable
    opacity: 0.5
    cursor: 'ns-resize'
    axis: 'y'
    update: (event, ui) ->
      newOrder = []
      $(event.target).children('li').each (index, element) ->
        newOrder.push $(element).data('publication-id')

      Meteor.call 'reorder-collection', Session.get('currentCollectionId'), newOrder, (error) ->
        return FlashMessage.fromError error, true if error

Template.collectionSettings.helpers
  canModify: ->
    return unless @_id
    @hasMaintainerAccess Meteor.person @constructor.maintainerAccessPersonFields()

  canRemove: ->
    return unless @_id
    @hasRemoveAccess Meteor.person @constructor.removeAccessPersonFields()

Template.collectionAdminTools.events
  'click .dropdown-trigger': (event, template) ->
    # Make sure only the trigger toggles the dropdown, by
    # excluding clicks inside the content of this dropdown
    return if $.contains template.find('.dropdown-anchor'), event.target

    template.$('.dropdown-anchor').toggle()

    return # Make sure CoffeeScript does not return anything

  'click .delete-collection': (event, template) ->
    Meteor.call 'remove-collection', @_id, (error, count) =>
      FlashMessage.fromError error, true if error

      return unless count

      FlashMessage.success "Collection removed."
      # TODO: Consider redirecting back to the page where we came from (maybe /c, maybe /library)
      Meteor.Router.toNew Meteor.Router.libraryPath()

    return # Make sure CoffeeScript does not return anything

# This provides functionality of the library menu (from publication.html) that is specific to the collection view
Template.publicationLibraryMenuButtons.helpers
  inCurrentCollection: ->
    return unless @_id

    Collection.documents.findOne
      _id: Session.get 'currentCollectionId'
      'publications._id': @_id

Template.publicationLibraryMenuButtons.events
  'click .remove-from-current-collection': (event, template) ->
    return unless Meteor.personId()

    collection = Collection.documents.findOne
      _id: Session.get 'currentCollectionId'
      'publications._id': @_id

    return unless collection

    Meteor.call 'remove-from-library', @_id, collection._id, (error, count) =>
      return FlashMessage.fromError error, true if error

      FlashMessage.success "Publication removed from the collection." if count

    return # Make sure CoffeeScript does not return anything

Template.registerHelper 'isCollection', ->
  @ instanceof Collection

Template.registerHelper 'collectionPathFromId', _.bind Collection.pathFromId, Collection

Template.registerHelper 'collectionReference', _.bind Collection.reference, Collection
