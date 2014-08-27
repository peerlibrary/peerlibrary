Template.collections.catalogSettings = ->
  subscription: 'collections'
  documentClass: Collection
  variables:
    active: 'collectionsActive'
    ready: 'currentCollectionsReady'
    loading: 'currentCollectionsLoading'
    count: 'currentCollectionsCount'
    filter: 'currentCollectionsFilter'
    limit: 'currentCollectionsLimit'
    limitIncreasing: 'currentCollectionsLimitIncreasing'
    sort: 'currentCollectionsSort'
  signedInNoDocumentsMessage: "Create the first using the form on the right."
  signedOutNoDocumentsMessage: "Sign in and create the first."

Deps.autorun ->
  if Session.equals 'collectionsActive', true
    Meteor.subscribe 'my-collections'

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
      return FlashMessage.fromError error, true if error

      # Clear the collection name from the form
      $(template.findAll '.name').val('')

      FlashMessage.success "Collection created."

    return # Make sure CoffeeScript does not return anything

Editable.template Template.collectionCatalogItemName, ->
  @data.hasMaintainerAccess Meteor.person @data.constructor.maintainerAccessPersonFields()
,
  (name) ->
    Meteor.call 'collection-set-name', @data._id, name, (error, count) ->
      return FlashMessage.fromError error, true if error
,
  "Enter collection name"
,
  false

EnableCatalogItemLink Template.collectionCatalogItem

Template.collectionCatalogItem.private = ->
  @access is ACCESS.PRIVATE

Template.collectionCatalogItem.countDescription = ->
  Publication.verboseNameWithCount @publications?.length
