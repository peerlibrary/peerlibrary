# Used for global variable assignments in local scopes
root = @

Catalog.create 'publications', Publication,
  main: Template.publications
  empty: Template.noPublications
  loading: Template.publicationsLoading
,
  active: 'publicationsActive'
  ready: 'currentPublicationsReady'
  loading: 'currentPublicationsLoading'
  count: 'currentPublicationsCount'
  filter: 'currentPublicationsFilter'
  limit: 'currentPublicationsLimit'
  sort: 'currentPublicationsSort'

Template.publications.catalogSettings = ->
  documentClass: Publication
  variables:
    filter: 'currentPublicationsFilter'
    sort: 'currentPublicationsSort'

Template.publicationCatalogItem.events =
  'click .preview-link': (e, template) ->
    e.preventDefault()

    if template._publicationHandle
      # We ignore the click if handle is not yet ready
      $(template.findAll '.abstract').slideToggle('fast') if template._publicationHandle.ready()
    else
      template._publicationHandle = Meteor.subscribe 'publications-by-id', @_id, =>
        Deps.afterFlush =>
          $(template.findAll '.abstract').slideToggle('fast')

    return # Make sure CoffeeScript does not return anything

Template.publicationCatalogItem.created = ->
  @_publicationHandle = null

Template.publicationCatalogItem.rendered = ->
  $(@findAll '.scrubber').iscrubber()

Template.publicationCatalogItem.destroyed = ->
  @_publicationHandle?.stop()
  @_publicationHandle = null

Template.publicationCatalogItem.hasAbstract = ->
  @hasAbstract or @abstract

libraryMenuSubscriptionCounter = 0
libraryMenuSubscriptionPersonHandle = null
libraryMenuSubscriptionCollectionsHandle = null

onDropdownHidden = (event) ->
  $toolbar = $(this).parents(".toolbar")
  $item = $toolbar.parents(".catalog-item")
  $toolbar.removeClass("displayed")
  $item.removeClass("active").css('z-index','0')

Template.publicationCatalogItemLibraryMenu.rendered = ->
  $(@findAll '.dropdown-anchor').off('dropdown-hidden').on('dropdown-hidden', onDropdownHidden)

Template.publicationCatalogItemLibraryMenu.events
  'click .toolbar-button': (e, template) ->

    $anchor = $(template.findAll '.dropdown-anchor')
    $anchor.toggle()

    $toolbar = $(template.firstNode).parents(".toolbar")
    $item = $toolbar.parents(".catalog-item")

    if $anchor.is(':visible')
      $toolbar.addClass("displayed")
      $item.addClass("active").css('z-index','10')

    else
      onDropdownHidden.call($anchor, null)

    # We only subscribe to person's collections on click, because they are not immediately seen.
    libraryMenuSubscriptionCollectionsHandle = Meteor.subscribe 'my-collections' unless libraryMenuSubscriptionCollectionsHandle

    return # Make sure CoffeeScript does not return anything

Template.publicationCatalogItemLibraryMenu.inLibrary = Template.publicationLibraryMenuButtons.inLibrary

Template.publicationCatalogItemLibraryMenu.created = ->
  libraryMenuSubscriptionCounter++
  # We need to subscribe to person's library here, because the icon of the menu changes to reflect in-library status.
  libraryMenuSubscriptionPersonHandle = Meteor.subscribe 'my-person-library' unless libraryMenuSubscriptionPersonHandle

Template.publicationCatalogItemLibraryMenu.destroyed = ->
  libraryMenuSubscriptionCounter--

  unless libraryMenuSubscriptionCounter
    libraryMenuSubscriptionPersonHandle?.stop()
    libraryMenuSubscriptionPersonHandle = null
    libraryMenuSubscriptionCollectionsHandle?.stop()
    libraryMenuSubscriptionCollectionsHandle = null

Editable.template Template.publicationCatalogItemTitle, ->
  @data.hasMaintainerAccess Meteor.person()
,
(title) ->
  Meteor.call 'publication-set-title', @data._id, title, (error, count) ->
    return Notify.meteorError error, true if error
,
  "Enter publication title"

Template.publicationMetaMenuTitle[method] = Template.publicationCatalogItemTitle[method] for method in ['created', 'rendered', 'destroyed']

Template.publicationCatalogItemThumbnail.events
  'click li': (e, template) ->
    root.startViewerOnPage = @page
    # TODO: Change when you are able to access parent context directly with Meteor
    publication = @publication
    Meteor.Router.toNew Meteor.Router.publicationPath publication._id, publication.slug
