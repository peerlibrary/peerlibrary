Deps.autorun ->
  if Session.equals 'libraryActive', true

    currentUserId = Meteor.personId()

    Meteor.subscribe 'persons-by-id-or-slug', currentUserId

    Meteor.subscribe 'my-publications'
    Meteor.subscribe 'my-publications-importing'

    Meteor.subscribe 'my-collections'

# Publications in logged user's library
Template.library.myPublications = ->
  Publication.documents.find
    _id:
      $in: _.pluck Meteor.person()?.library, '_id'

Template.collections.myCollections = ->
  return unless Meteor.person()

  libraryCollection =
    name: "All Publications"
    author: Meteor.person()
    publications: Publication.documents.find
      _id:
        $in: _.pluck Meteor.person().library, '_id'
    .fetch()

  collections = Collection.documents.find
    'author._id': Meteor.personId()
  .fetch()

  [libraryCollection].concat collections

Template.collections.events
  'submit .add-collection': (e, template) ->
    e.preventDefault()
    Collection.documents.insert
      name: $(template.findAll '.name').val()
      author: Meteor.person()
    ,
      (error, id) =>
        return Notify.meteorError error, true if error

        Notify.success "Collection created."
        Meteor.Router.toNew Meteor.Router.collectionPath id

    return # Make sure CoffeeScript does not return anything

Template.collectionListing.countDescription = ->
  if @publications.length is 1 then "1 publication" else "#{@publications.length} publications"