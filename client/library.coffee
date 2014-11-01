Tracker.autorun ->
  if Session.equals 'libraryActive', true
    Meteor.subscribe 'my-person-library'
    Meteor.subscribe 'my-publications'
    Meteor.subscribe 'my-collections'

Template.libraryPublications.helpers
  myLibrary: ->
    Meteor.person(library: 1)?.library or []

Template.libraryPublications.rendered = ->
  @$('.catalog-item').draggable
    opacity: 0.5
    revert: true
    revertDuration: 0
    cursor: 'move'
    zIndex: 2
    start: (event, ui) ->
      collections = $('.library-collections-wrapper')
      # When we start to drag a publication, we display collections fixed so they are in view, ready to be dropped onto.
      # TODO: Make sure this works for people with lots of collections.
      collections.addClass('fixed')
      # To prevent footer from moving up, force the containing row to be at least as high as the collections.
      collections.parent('.row').css('min-height', collections.outerHeight())
    stop: (event, ui) ->
      $('.library-collections-wrapper').removeClass('fixed')

Template.libraryMyCollections.helpers
  myCollections: Template.myCollections.helpers 'myCollections'

Template.libraryMyCollections.rendered = ->
  @$('.catalog-item').droppable
    accept: '.publication.catalog-item'
    activeClass: 'droppable-active'
    hoverClass: 'droppable-hover'
    tolerance: 'pointer'
    drop: (event, ui) ->
      publicationId = ui.draggable.data('publication-id')
      collectionId = $(event.target).data('collection-id')
      Meteor.call 'add-to-library', publicationId, collectionId, (error, count) =>
        # TODO: Same operation is handled in client/publication.coffee from the meta-menu. Sync both?
        return FlashMessage.fromError error, true if error

        FlashMessage.success "Publication added to collection." if count
