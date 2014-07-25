Catalog.create 'collections', Collection,
  main: Template.collections
  count: Template.collectionsCount
  loading: Template.collectionsLoading
,
  active: 'collectionsActive'
  ready: 'currentCollectionsReady'
  loading: 'currentCollectionsLoading'
  count: 'currentCollectionsCount'
  filter: 'currentCollectionsFilter'
  limit: 'currentCollectionsLimit'
  sort: 'currentCollectionsSort'

Deps.autorun ->
  if Session.equals 'collectionsActive', true
    Meteor.subscribe 'my-collections'

Template.collections.catalogSettings = ->
  documentClass: Collection
  variables:
    filter: 'currentCollectionsFilter'
    sort: 'currentCollectionsSort'

Template.myCollections.myCollections = ->
  return unless Meteor.personId()

  Collection.documents.find
    'authorPerson._id': Meteor.personId()
  ,
    sort: [
      ['slug', 'asc']
    ]

Template.addNewCollection.events
  'submit .add-collection': (e, template) ->
    e.preventDefault()

    name = $(template.findAll '.name').val().trim()
    return unless name

    Meteor.call 'create-collection', name, (error, collectionId) =>
      return Notify.meteorError error, true if error

      # Clear the collection name from the form
      $(template.findAll '.name').val('')

      Notify.success "Collection created."

    return # Make sure CoffeeScript does not return anything

Editable.template Template.collectionCatalogItemName, ->
  @data.hasMaintainerAccess Meteor.person @data.constructor.maintainerAccessPersonFields()
,
  (name) ->
    Meteor.call 'collection-set-name', @data._id, name, (error, count) ->
      return Notify.meteorError error, true if error
,
  "Enter collection name"
,
  false

Template.collectionCatalogItem.events =
  'mousedown': (e, template) ->
    # Save mouse position so we can later detect selection actions in click handler
    template.data._previousMousePosition =
      pageX: e.pageX
      pageY: e.pageY

  'click': (e, template) ->
    # Don't redirect if user interacted with one of the actionable controls on the item
    return if $(e.target).closest('.actionable').length > 0

    # Don't redirect if this might have been a selection
    e.previousMousePosition = template.data._previousMousePosition
    return if e.previousMousePosition and (Math.abs(e.previousMousePosition.pageX - e.pageX) > 1 or Math.abs(e.previousMousePosition.pageY - e.pageY) > 1)

    # Redirect user to the collection
    Meteor.Router.toNew Meteor.Router.collectionPath template.data._id, template.data.slug

Template.collectionCatalogItem.countDescription = ->
  Publication.verboseNameWithCount @publications?.length
