Deps.autorun ->
  if Session.equals 'libraryActive', true

    Meteor.subscribe 'my-person-library'

    Meteor.subscribe 'my-publications'
    # So that users can see their own filename of the imported file, before a publication has metadata
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
    cursor: 'move'
    zIndex: 1
    start: (e, ui) ->
      collections = $('.library-collections-wrapper')
      # When we start to drag a publication, we display collections fixed so they are in view, ready to be dropped onto.
      # TODO: Make sure this works for people with lots of collections.
      collections.addClass('fixed')
      # To prevent footer from moving up, force the containing row to be at least as high as the collections.
      collections.parent('.row').css('min-height', collections.outerHeight())
    stop: (e, ui) ->
      $('.library-collections-wrapper').removeClass('fixed')

Template.collections.myCollections = ->
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

Template.collections.rendered = ->
  $(@findAll '.collection-listing').droppable
    accept: '.result-item'
    activeClass: 'droppable-active'
    hoverClass: 'droppable-hover'
    tolerance: 'pointer'
    drop: (event, ui) ->
      publicationId = ui.draggable.data('publication-id')
      collectionId = $(event.target).data('collection-id')
      Meteor.call 'add-to-library', publicationId, collectionId, (error, count) =>
        # TODO: Same operation is handled in client/publication.coffee from the meta-menu. Sync both?
        return Notify.meteorError error, true if error

        Notify.success "Publication added to collection." if count

Template.collectionListing.countDescription = ->
  if @publications?.length is 1 then "1 publication" else "#{ @publications?.length or 0 } publications"