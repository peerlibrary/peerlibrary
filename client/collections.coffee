Catalog.create 'collections', Collection,
  main: Template.collections
  empty: Template.noCollections
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
  'submit .add-collection': (event, template) ->
    event.preventDefault()

    name = $(template.findAll '.name').val().trim()
    return unless name

    Meteor.call 'create-collection', name, (error, collectionId) =>
      return Notify.smartError error, true if error

      # Clear the collection name from the form
      $(template.findAll '.name').val('')

      Notify.success "Collection created."

    return # Make sure CoffeeScript does not return anything

Editable.template Template.collectionCatalogItemName, ->
  @data.hasMaintainerAccess Meteor.person @data.constructor.maintainerAccessPersonFields()
,
  (name) ->
    Meteor.call 'collection-set-name', @data._id, name, (error, count) ->
      return Notify.smartError error, true if error
,
  "Enter collection name"
,
  false

Template.collectionCatalogItem.countDescription = ->
  Publication.verboseNameWithCount @publications?.length
