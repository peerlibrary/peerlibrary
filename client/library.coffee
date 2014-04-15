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

  Publication.documents.find
    _id:
      $in: _.pluck person.library, '_id'

Template.libraryPublications.rendered = ->
  $(@findAll '.result-item').draggable
    opacity: 0.5
    revert: true
    revertDuration: 0
    zIndex: 1
    start: (e) ->
      $('.library-collections').addClass('fixed')
    stop: (e) ->
      $('.library-collections').removeClass('fixed')

Template.collections.myCollections = ->
  return unless Meteor.person()

  Collection.documents.find
    'author._id': Meteor.personId()
  ,
    sort: [
      ['slug', 'asc']
    ]

Template.addNewCollection.events

  'submit .add-collection': (e, template) ->
    e.preventDefault()
    Collection.documents.insert
      name: $(template.findAll '.name').val()
      author: Meteor.person()
      publications: []
    ,
      (error, id) =>
        return Notify.meteorError error, true if error

        $(template.findAll '.name').val('')

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