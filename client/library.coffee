Deps.autorun ->
  if Session.equals 'libraryActive', true

    currentUserId = Meteor.personId()

    Meteor.subscribe 'persons-by-id-or-slug', currentUserId

    Meteor.subscribe 'my-publications'
    Meteor.subscribe 'my-publications-importing'

    Meteor.subscribe 'my-collections'

allPublications = ->
  Publication.documents.find
    _id:
      $in: _.pluck Meteor.person()?.library, '_id'

allPublicationsCollection = ->
  name: "All Publications"
  publications: allPublications()

activeCollectionId = null
activeCollectionDependency = new Deps.Dependency

setActiveCollection = (collectionId) ->
  activeCollectionId = collectionId
  activeCollectionDependency.changed()

Template.collectionPublications.activeCollection = ->
  activeCollectionDependency.depend()

  return allPublicationsCollection() unless activeCollectionId

  Collection.documents.findOne
    '_id': activeCollectionId

Template.collectionPublications.rendered = ->
  $(@findAll '.collection-publications').sortable()

# Publications in logged user's library
Template.collections.allPublications = ->
  allPublications()

countDescription = (publications) ->
  return "0 publications" unless publications
  if publications.length is 1 then "1 publication" else "#{publications.length} publications"

Template.collections.allPublicationsCountDescription = ->
  countDescription Meteor.person()?.library

Template.collections.myCollections = ->
  return unless Meteor.person()

  Collection.documents.find
    'author._id': Meteor.personId()

Template.collections.events
  'click .all-publications': (e, template) ->
    setActiveCollection null

    return # Make sure CoffeeScript does not return anything

  'click .collection-listing': (e, template) ->
    setActiveCollection this._id

    return # Make sure CoffeeScript does not return anything

  'submit .add-collection': (e, template) ->
    e.preventDefault()
    Collection.documents.insert
      name: $(template.findAll '.name').val()
      author: Meteor.person()
      publications: []
    ,
      (error, id) =>
        return Notify.meteorError error, true if error

        Notify.success "Collection created."

    return # Make sure CoffeeScript does not return anything

Template.collections.rendered = ->
  $(@findAll '.collection-listing').droppable
    accept: '.result-item'
    activeClass: 'droppable-active'
    hoverClass: 'droppable-hover'
    tolerance: 'pointer'
    drop: (event, ui) ->
      console.log "dropped!"
      console.log event

Template.collectionListing.countDescription = ->
  countDescription @publications