# Used for global variable assignments in local scopes
globals = @

Template.publications.helpers
  catalogSettings: ->
    subscription: 'publications'
    documentClass: Publication
    variables:
      active: 'publicationsActive'
      ready: 'currentPublicationsReady'
      loading: 'currentPublicationsLoading'
      count: 'currentPublicationsCount'
      filter: 'currentPublicationsFilter'
      limit: 'currentPublicationsLimit'
      limitIncreasing: 'currentPublicationsLimitIncreasing'
      sort: 'currentPublicationsSort'
    signedInNoDocumentsMessage: "Import the first from the menu on top."
    signedOutNoDocumentsMessage: "Sign in and import the first."

slideToggle = (template) ->
  slide = if template._abstractOpen then 'slideUp' else 'slideDown'
  template.$('.abstract').velocity slide, 'fast'
  template._abstractOpen = not template._abstractOpen

Template.publicationCatalogItem.events
  'click .preview-link': (event, template) ->
    event.preventDefault()

    if template._publicationHandle
      # We ignore the click if handle is not yet ready
      slideToggle template if template._publicationHandle.ready()
    else
      template._publicationHandle = Meteor.subscribe 'publication-by-id', @_id, =>
        Tracker.afterFlush =>
          slideToggle template

    return # Make sure CoffeeScript does not return anything

EnableCatalogItemLink Template.publicationCatalogItem

Template.publicationCatalogItem.created = ->
  @_publicationHandle = null
  @_abstractOpen = false

Template.publicationCatalogItem.rendered = ->
  @$('.scrubber').iscrubber
    direction: 'combined'

Template.publicationCatalogItem.destroyed = ->
  @_publicationHandle?.stop()
  @_publicationHandle = null
  @_abstractOpen = null

Template.publicationCatalogItem.helpers
  documentLengthClass: ->
    return unless @_id

    switch
      when @numberOfPages < 10 then 'short'
      when @numberOfPages < 25 then 'medium'
      else 'long'

  annotationsCountDescription: ->
    Annotation.verboseNameWithCount @annotationsCount

  hasAbstract: ->
    @abstract ? @hasAbstract

  hasCachedId: ->
    @cachedId ? @hasCachedId

  open: ->
    @access is Publication.ACCESS.OPEN

  closed: ->
    @access is Publication.ACCESS.CLOSED

  private: ->
    @access is Publication.ACCESS.PRIVATE

libraryMenuSubscriptionCounter = 0
libraryMenuSubscriptionPersonHandle = null
libraryMenuSubscriptionCollectionsHandle = null

onLibraryDropdownHidden = (event) ->
  # Return the library button to default state.
  $toolbar = $(this).parents('.toolbar')
  $toolbar.removeClass('displayed')
  $item = $toolbar.parents('.catalog-item')
  $item.removeClass('active').css('z-index','0')
  $button = $toolbar.find('.toolbar-button')
  $button.addClass('tooltip')

Template.publicationCatalogItemLibraryMenu.rendered = ->
  @$('.dropdown-anchor').off('dropdown-hidden').on('dropdown-hidden', onLibraryDropdownHidden)

Template.publicationCatalogItemLibraryMenu.events
  'click .toolbar-button': (event, template) ->

    $anchor = template.$('.dropdown-anchor')
    $anchor.toggle()

    if $anchor.is(':visible')
      # Because the dropdown is active, make sure toolbar doesn't disappear when not hovered
      $toolbar = $(template.firstNode).parents('.toolbar')
      $toolbar.addClass('displayed')

      # Also make sure the catalog item is on top of other items,
      # since the dropdown extends out of it
      $item = $toolbar.parents('.catalog-item')
      $item.addClass('active').css('z-index','10')

      # Temporarily remove and disable tooltips on the button, because the same
      # information as in the tooltip is displayed in the dropdown content. We need
      # to remove the element manually, since we can't selectively disable/destroy
      # it just on this element through jQeury UI.
      $button = template.$('.toolbar-button')
      tooltipId = $button.attr('aria-describedby')
      $('#' + tooltipId).remove()
      $button.removeClass('tooltip')

    else
      onLibraryDropdownHidden.call($anchor, null)

    # We only subscribe to person's collections on click, because they are not immediately seen
    libraryMenuSubscriptionCollectionsHandle = Meteor.subscribe 'my-collections' unless libraryMenuSubscriptionCollectionsHandle

    return # Make sure CoffeeScript does not return anything

Template.publicationCatalogItemLibraryMenu.helpers
  inLibrary: Template.publicationLibraryMenuButtons.helpers 'inLibrary'

Template.publicationCatalogItemLibraryMenu.created = ->
  libraryMenuSubscriptionCounter++
  # We need to subscribe to person's library here, because the icon of the menu changes to reflect in-library status
  libraryMenuSubscriptionPersonHandle = Meteor.subscribe 'my-person-library' unless libraryMenuSubscriptionPersonHandle

Template.publicationCatalogItemLibraryMenu.destroyed = ->
  libraryMenuSubscriptionCounter--

  unless libraryMenuSubscriptionCounter
    libraryMenuSubscriptionPersonHandle?.stop()
    libraryMenuSubscriptionPersonHandle = null
    libraryMenuSubscriptionCollectionsHandle?.stop()
    libraryMenuSubscriptionCollectionsHandle = null

Editable.template Template.publicationCatalogItemTitle, ->
  data = Template.currentData()
  return unless data
  # TODO: Not all necessary fields for correct access check are present in search results/catalog, we should preprocess permissions this in a middleware and send computed permission as a boolean flag
  data.hasMaintainerAccess Meteor.person data.constructor.maintainerAccessPersonFields()
,
  (title) ->
    title = title.trim()
    return unless title
    Meteor.call 'publication-set-title', Template.currentData()._id, title, (error, count) ->
      return FlashMessage.fromError error, true if error
,
  "Enter publication title"

Template.publicationMetaMenuTitle[method] = Template.publicationCatalogItemTitle[method] for method in ['created', 'rendered', 'destroyed']

Template.publicationCatalogItemThumbnail.events
  'mouseenter li': (event, template) ->
    # Update page tooltip with current scrubbed over page
    $(template.firstNode).closest('.thumbnail').find('.ui-tooltip').text("Page #{ @page } of #{ @publication.numberOfPages }")

    return # Make sure CoffeeScript does not return anything

  'click li': (event, template) ->
    globals.startViewerOnPage = @page

    publication = Template.parentData 1
    Meteor.Router.toNew Meteor.Router.publicationPath publication._id, publication.slug

    return # Make sure CoffeeScript does not return anything
