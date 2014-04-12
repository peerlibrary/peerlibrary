Deps.autorun ->
  if Session.equals 'libraryActive', true

    currentUserId = Meteor.personId()

    Meteor.subscribe 'persons-by-id-or-slug', currentUserId

    Meteor.subscribe 'my-publications'
    Meteor.subscribe 'my-publications-importing'

    Meteor.subscribe 'my-collections'

Template.libraryPublications.myPublications = ->
  person = Meteor.person()
  return unless person

  publications = Publication.documents.find
    _id:
      $in: _.pluck person.library, '_id'
  .fetch()

  # Order documents according to library
  _.map person.library, (libraryPublication) ->
    _.find publications, (publication) ->
      libraryPublication._id is publication._id

Template.libraryPublications.rendered = ->
  $(@findAll '.library-publications').sortable
    opacity: 0.5
    update: (event, ui) ->
      newOrder = []
      $(this).children("li").each () ->
        newOrder.push $(this).attr("data-id")

      Meteor.call "reorder-library", newOrder

Template.collections.myCollections = ->
  return unless Meteor.person()

  Collection.documents.find
    'author._id': Meteor.personId()

Template.collections.events

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
      publicationId = ui.draggable.attr("data-id")
      collectionId = $(this).attr("data-id")
      Meteor.call 'add-to-collection', collectionId, publicationId

Template.collectionListing.countDescription = ->
  return "0 publications" unless @publications
  if @publications.length is 1 then "1 publication" else "#{@publications.length} publications"
