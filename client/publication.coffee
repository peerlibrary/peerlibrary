@SCALE = 1.25

draggingViewport = false
currentPublication = null
publicationHandle = null
publicationCacheHandle = null

# If set to an annotation id, focus on next render
focusAnnotationId = null

# We use our own reactive variable for publicationDOMReady and not Session to
# make sure it is not preserved when site autoreloads (because of a code change).
# Otherwise publicationDOMReady stored in Session would be restored to true which
# would be an invalid initial state. But on the other hand we want it to be
# a reactive value so that we can combine code logic easy.
publicationDOMReady = new Variable false

# Mostly used just to force reevaluation of publicationHandle and publicationCacheHandle
publicationSubscribing = new Variable false

# To be able to limit shown annotations only to those with highlights in the current viewport
currentViewport = new Variable
  top: null
  bottom: null

# Variable containing currently realized (added to the DOM) highlights
@currentHighlights = new KeysEqualityVariable {}

ANNOTATION_DEFAULTS =
  access: Annotation.ACCESS.PUBLIC
  groups: []

Meteor.startup ->
  Session.setDefault 'annotationDefaults', ANNOTATION_DEFAULTS

getAnnoationDefaults = ->
  _.defaults Session.get('annotationDefaults'), ANNOTATION_DEFAULTS

Deps.autorun ->
  # We have to keep list of default groups updated if user is removed from a group
  Group.documents.find(_id: $in: _.pluck Meteor.person()?.inGroups, '_id').observeChanges
    removed: (id) ->
      defaults = getAnnoationDefaults()
      defaults.groups = _.without defaults.groups, id
      Session.set 'annotationDefaults', defaults

class @Publication extends Publication
  @Meta
    name: 'Publication'
    replaceParent: true

  constructor: (args...) ->
    super args...

    @_pages = null
    @_highlighter = null

  _viewport: (page) =>
    scale = SCALE
    page.pdfPage.getViewport scale

  _progressCallback: (progressData) =>
    # Maybe this instance has been destroyed in meantime
    return if @_pages is null

    @_progressData = progressData if progressData

    documentHalf = _.min [(@_progressData.loaded / @_progressData.total) / 2, 0.5]
    pagesHalf = if @_pdf then (@_pagesDone / @_pdf.numPages) / 2 else 0

    Session.set 'currentPublicationProgress', documentHalf + pagesHalf

  show: (@_$displayWrapper) =>
    Notify.debug "Showing publication #{ @_id }"

    switch @mediaType
      when 'pdf' then @showPDF()
      when 'tei' then @showTEI()
      else Notify.error "Unsupported media type: #{ @mediaType }", null, true

  showPDF: =>
    assert.strictEqual @_pages, null

    @_pagesDone = 0
    @_pages = []
    @_highlighter = new Highlighter @_$displayWrapper, true

    focusAnnotationId = null

    PDFJS.getDocument(@url(), null, null, @_progressCallback).then (@_pdf) =>
      # Maybe this instance has been destroyed in meantime
      return if @_pages is null

      # To make sure we are starting with empty slate
      @_$displayWrapper.empty()
      publicationDOMReady.set false
      currentViewport.set
        top: null
        bottom: null
      currentHighlights.set {}

      @_highlighter.setNumPages @_pdf.numPages

      for pageNumber in [1..@_pdf.numPages]
        $displayCanvas = $('<canvas/>').addClass('display-canvas').addClass('content-background').data('page-number', pageNumber)
        $highlightsCanvas = $('<canvas/>').addClass('highlights-canvas')
        $highlightsLayer = $('<div/>').addClass('highlights-layer')
        # We enable forwarding of mouse events from selection layer to highlights layer
        $selectionLayer = $('<div/>').addClass('text-layer').addClass('selection-layer').forwardMouseEvents()
        $highlightsControl = $('<div/>').addClass('highlights-control').append(
          $('<div/>').addClass('meta-menu').append(
            $('<i/>').addClass('icon-menu'),
            $('<div/>').addClass('meta-content'),
          )
        )
        $loading = $('<div/>').addClass('loading').text("Page #{ pageNumber }")

        $('<div/>').addClass(
          'display-page'
        ).addClass(
          'display-page-loading'
        ).attr(
          id: "display-page-#{ pageNumber }"
        ).append(
          $displayCanvas,
          $highlightsCanvas,
          $highlightsLayer,
          $selectionLayer,
          $highlightsControl,
          $loading,
        ).appendTo(@_$displayWrapper)

        do (pageNumber) =>
          @_pdf.getPage(pageNumber).then (pdfPage) =>
            # Maybe this instance has been destroyed in meantime
            return if @_pages is null

            assert.equal pageNumber, pdfPage.pageNumber

            viewport = @_viewport
              pdfPage: pdfPage # Dummy page object

            $displayPage = $("#display-page-#{ pdfPage.pageNumber }", @_$displayWrapper).removeClass('display-page-loading')
            $canvas = $displayPage.find('canvas') # Both display and highlights canvases
            $canvas.attr
              height: viewport.height
              width: viewport.width
            $displayPage.css
              height: viewport.height
              width: viewport.width

            # TODO: We currently change this based on the width of the last page, but pages might not be of same width, what can we do then?

            # We remove all added CSS in publication destroy
            $('footer.publication').add(@_$displayWrapper).css
              width: viewport.width
            resizeAnnotationsControl()

            $('.annotations-list .invite .body, .annotations-list .local .body').balanceText()

            @_pages[pageNumber - 1] =
              pageNumber: pageNumber
              pdfPage: pdfPage
              rendering: false
            @_pagesDone++

            @_highlighter.setPage pdfPage

            @_getTextContent pdfPage

            @_progressCallback()

            # Check if new page should be maybe rendered?
            @checkRender()

            publicationDOMReady.set true if @_pagesDone is @_pdf.numPages

          , (args...) =>
            # TODO: Handle errors better (call destroy?)
            Notify.error "Error getting page #{ pageNumber }", args

      $(window).on 'scroll.publication resize.publication', @checkRender

    , (args...) =>
      # TODO: Handle errors better (call destroy?)
      Notify.error "Error showing #{ @_id }", args

    currentPublication = @

  _getTextContent: (pdfPage) =>
    Notify.debug "Getting text content for page #{ pdfPage.pageNumber }"

    pdfPage.getTextContent().then (textContent) =>
      # Maybe this instance has been destroyed in meantime
      return if @_pages is null

      @_highlighter.setTextContent pdfPage.pageNumber, textContent

      # In addition to set text content for highlighter we also create
      # a dummy text layer containing text. The idea is that while we
      # do not yet have precise location of the text on the page and
      # we do not even want all pages to have a realistic text layer
      # because it is very resource heavy, we can create one div with
      # all text in it so that when user searchers in the browser,
      # browser can find the page. And once it jumps to the page we
      # render a realistic text layer and hude the dummy one. This text
      # is hidden, but we force it over the whole page, so that those
      # yellow lines in the scroll bar in Chrome showing the position
      # of search results are more or less accurate. All this is just
      # a workaround and it is not ideal because once browser jumps to
      # the page and renders the realistic text layer user has to repeat
      # the search for browser to find content in the new text layer.
      # We could decide in the future to rather intercept search,
      # for example by intercepting ctrl+f.

      # Good initial font size, we want text to cover whole page,
      # but if there is not much text to begin with, we should not
      # make it too big
      fontSize = 21

      $displayPage = $("#display-page-#{ pdfPage.pageNumber }", @_$displayWrapper)
      $textLayerDummy = $('<div/>').addClass('text-layer-dummy').css('font-size', fontSize).text(@_highlighter.extractText pdfPage.pageNumber)
      $displayPage.append($textLayerDummy)

      while $textLayerDummy.outerHeight(true) > $displayPage.height() and fontSize > 1
        fontSize--
        $textLayerDummy.css('font-size', fontSize)

      Notify.debug "Getting text content for page #{ pdfPage.pageNumber } complete"

      # Check if the page should be maybe rendered, but we
      # skipped it because text content was not yet available
      @checkRender()

    , (args...) =>
      # TODO: Handle errors better (call destroy?)
      Notify.error "Error getting text content for page #{ pdfPage.pageNumber }", args

  checkRender: =>
    for page in @_pages or []
      continue if page.rendering

      # When rendering we also set text segment locations for what we need text
      # content to be already available, so if we are before text content has
      # been set, we skip (it will be retried after text content is set)
      continue unless @_highlighter.hasTextContent page.pageNumber

      $canvas = $("#display-page-#{ page.pageNumber } canvas", @_$displayWrapper)

      canvasTop = $canvas.offset().top
      canvasBottom = canvasTop + $canvas.height()
      # Add 100px so that we start rendering early
      if canvasTop - 100 <= $(window).scrollTop() + $(window).height() and canvasBottom + 100 >= $(window).scrollTop()
        @renderPage page

    return # Make sure CoffeeScript does not return anything

  destroy: =>
    Notify.debug "Destroying publication #{ @_id }"

    currentPublication = null
    focusAnnotationId = null

    pages = @_pages or []
    @_pages = null # To remove references to pdf.js elements to allow cleanup, and as soon as possible as this disables other callbacks

    $(window).off '.publication'

    page.pdfPage.destroy() for page in pages
    if @_pdf
      @_pdf.cleanup()
      @_pdf.destroy()
      @_pdf = null

    # To make sure it is cleaned up
    @_highlighter.destroy() if @_highlighter
    @_highlighter = null

    # Clean DOM
    @_$displayWrapper.empty()

    # We remove added CSS
    $('footer.publication').add(@_$displayWrapper).css
      width: ''
    $('.annotations-control, .annotations-list').css
      left: ''

    @_$displayWrapper = null

    publicationDOMReady.set false
    currentViewport.set
      top: null
      bottom: null
    currentHighlights.set {}

  renderPage: (page) =>
    return if page.rendering
    page.rendering = true

    Notify.debug "Rendering page #{ page.pdfPage.pageNumber }"

    $displayPage = $("#display-page-#{ page.pageNumber }", @_$displayWrapper)
    $canvas = $displayPage.find('canvas')

    # Redo canvas resize to make sure it is the right size
    # It seems sometimes already resized canvases are being deleted and replaced with initial versions
    viewport = @_viewport page
    $canvas.attr
      height: viewport.height
      width: viewport.width
    $displayPage.css
      height: viewport.height
      width: viewport.width

    renderContext =
      canvasContext: $canvas.get(0).getContext '2d'
      textLayer: @_highlighter.textLayer page.pageNumber
      imageLayer: @_highlighter.imageLayer page.pageNumber
      viewport: @_viewport page

    page.pdfPage.render(renderContext).promise.then =>
      # Maybe this instance has been destroyed in meantime
      return if @_pages is null

      Notify.debug "Rendering page #{ page.pdfPage.pageNumber } complete"

      $("#display-page-#{ page.pageNumber } .loading", @_$displayWrapper).hide()

      # Maybe we have to render text layer as well
      @_highlighter.checkRender()

    , (args...) =>
      # TODO: Handle errors better (call destroy?)
      Notify.error "Error rendering page #{ page.pdfPage.pageNumber }", args

  showTEI: =>
    focusAnnotationId = null

    # To make sure we are starting with empty slate
    @_$displayWrapper.empty()
    publicationDOMReady.set false
    currentViewport.set
      top: null
      bottom: null
    currentHighlights.set {}

    # TODO: Handle errors
    $.ajax
      url: @url()
      dataType: 'xml'
      success: (xml, textStatus, jqXHR) =>
        $.ajax
          url: '/tei/tei.xsl'
          dataType: 'xml'
          success: (xsl, textStatus, jqXHR) =>
            xsltProcessor = new XSLTProcessor()
            xsltProcessor.importStylesheet xsl
            fragment = xsltProcessor.transformToFragment xml, document
            try
              # We append the fragment to DOM so that we can process it with jQuery.
              # jQuery has some issues working on the fragment otherwise. It still
              # throws an exception when appending, so we catch it and ignore it.
              @_$displayWrapper.append(fragment)
            catch error
              # We ignore a jQuery exception while appending
            # Now we remove it from DOM, temporary, cleaned and working for further processing
            $teiWrapper = @_$displayWrapper.find('html').remove().find('#tei_wrapper')

            # We remove teiheader element. We have to traverse the tree manually because jQuery selector does not find it.
            # TODO: We should parse this on the server side and create an annotation
            $teiWrapper.find('* > *').each (i, element) =>
              $(element).remove() if element.tagName.toLowerCase() is 'teiheader'

            # We enable highlighting on this layer and enable forwarding of mouse
            # events from selection layer to highlights layer
            $teiWrapper.addClass('selection-layer').forwardMouseEvents()

            $contentBackground = $('<div/>').addClass('content-background')
            $highlightsCanvas = $('<canvas/>').addClass('highlights-canvas')
            $highlightsLayer = $('<div/>').addClass('highlights-layer')
            $highlightsControl = $('<div/>').addClass('highlights-control').append(
              $('<div/>').addClass('meta-menu').append(
                $('<i/>').addClass('icon-menu'),
                $('<div/>').addClass('meta-content'),
              )
            )

            $displayPage = $('<div/>').addClass(
              'display-page'
            ).append(
              $contentBackground,
              $highlightsCanvas,
              $highlightsLayer,
              $teiWrapper,
              $highlightsControl
            ).appendTo(@_$displayWrapper)

            $displayPage.find('canvas').attr
              height: $teiWrapper.height()
              width: $teiWrapper.width()
            $displayPage.css
              height: $teiWrapper.height()
              width: $teiWrapper.width()

            # TODO: Update sizes as display page changes size (if user changes font size, for example)
            # TODO: Allow modifying size of display page (update then all sizes as necessary)

            @_highlighter = new Highlighter @_$displayWrapper, false
            @_highlighter.setNumPages 0
            @_highlighter._checkHighlighting()

            publicationDOMReady.set true

  # Fields needed when displaying (rendering) the publication: those which are needed for PDF URL to be available
  @DISPLAY_FIELDS: ->
    fields:
      cachedId: 1
      mediaType: 1

Deps.autorun ->
  if Session.get 'currentPublicationId'
    publicationSubscribing.set true
    publicationHandle = Meteor.subscribe 'publications-by-id', Session.get 'currentPublicationId'
    publicationCacheHandle = Meteor.subscribe 'publications-cached-by-id', Session.get 'currentPublicationId'
    Meteor.subscribe 'highlights-by-publication', Session.get 'currentPublicationId'
    Meteor.subscribe 'annotations-by-publication', Session.get 'currentPublicationId'
    Meteor.subscribe 'comments-by-publication', Session.get 'currentPublicationId'
    Meteor.subscribe 'my-groups'
  else
    publicationSubscribing.set false
    publicationHandle = null
    publicationCacheHandle = null

Deps.autorun ->
  if publicationSubscribing() and publicationHandle?.ready() and publicationCacheHandle?.ready()
    publicationSubscribing.set false

Deps.autorun ->
  publication = Publication.documents.findOne Session.get('currentPublicationId'),
    fields:
      _id: 1
      slug: 1

  return unless publication

  # currentPublicationSlug is null if slug is not present in location, so we use
  # null when publication.slug is empty string to prevent infinite looping
  return if Session.equals 'currentPublicationSlug', (publication.slug or null)

  highlightId = Session.get 'currentHighlightId'
  annotationId = Session.get 'currentAnnotationId'
  if highlightId
    Meteor.Router.toNew Meteor.Router.highlightPath publication._id, publication.slug, highlightId
  else if annotationId
    Meteor.Router.toNew Meteor.Router.annotationPath publication._id, publication.slug, annotationId
  else
    Meteor.Router.toNew Meteor.Router.publicationPath publication._id, publication.slug

Deps.autorun ->
  return unless Session.get 'currentPublicationId'

  # No editor unless logged in
  return unless Meteor.person()

  localAnnotation = LocalAnnotation.documents.findOne
    local: true
    'author._id': Meteor.personId()
    'publication._id': Session.get 'currentPublicationId'

  return if localAnnotation

  # There should always be one local annotation (the editor)
  annotation = createAnnotationDocument()
  annotation.local = true

  LocalAnnotation.documents.insert annotation

Template.publication.loading = ->
  publicationSubscribing() # To register dependency
  not publicationHandle?.ready() or not publicationCacheHandle?.ready()

Template.publication.notfound = ->
  publicationSubscribing() # To register dependency
  publicationHandle?.ready() and publicationCacheHandle?.ready() and not Publication.documents.findOne Session.get('currentPublicationId'), fields: _id: 1

Template.publication.publication = ->
  Publication.documents.findOne Session.get 'currentPublicationId'

addAccessEvents =
  'mousedown .add-access, mouseup .add-access': (e, template) ->
    # A special case to prevent defocus after click on the input box
    e.stopPropagation()
    return # Make sure CoffeeScript does not return anything

  'focus .add-access': (e, template) ->
    $(template.findAll '.meta-menu').addClass('displayed')
    return # Make sure CoffeeScript does not return anything

  'blur .add-access': (e, template) ->
    $(template.findAll '.meta-menu').removeClass('displayed')
    return # Make sure CoffeeScript does not return anything

Template.publicationMetaMenu.events addAccessEvents

Template.publicationAccessControl.open = ->
  @access is Publication.ACCESS.OPEN

Template.publicationAccessControl.closed = ->
  @access is Publication.ACCESS.CLOSED

Template.publicationAccessControl.private = ->
  @access is Publication.ACCESS.PRIVATE

# We copy over event handlers from accessControl template (which are general enough to work)
for spec, callbacks of Template.accessControl._tmpl_data.events
  for callback in callbacks
    eventMap = {}
    eventMap[spec] = callback
    Template.publicationAccessControl.events eventMap

libraryMenuSubscriptionCounter = 0
libraryMenuSubscriptionPersonHandle = null
libraryMenuSubscriptionCollectionsHandle = null

Template.publicationLibraryMenu.created = ->
  libraryMenuSubscriptionCounter++
  # We need to subscribe to person's library here, because the icon of the menu changes to reflect in-library status.
  libraryMenuSubscriptionPersonHandle = Meteor.subscribe 'persons-by-id-or-slug', Meteor.personId() unless libraryMenuSubscriptionPersonHandle

Template.publicationLibraryMenu.destroyed = ->
  libraryMenuSubscriptionCounter--

  unless libraryMenuSubscriptionCounter
    libraryMenuSubscriptionPersonHandle.stop() if libraryMenuSubscriptionPersonHandle
    libraryMenuSubscriptionPersonHandle = null
    libraryMenuSubscriptionCollectionsHandle.stop() if libraryMenuSubscriptionCollectionsHandle
    libraryMenuSubscriptionCollectionsHandle = null

Template.publicationLibraryMenu.events
  'mouseenter .library-menu': (e, template) ->
    # We only subscribe to person's collections on hover, because they are not immediately seen.
    libraryMenuSubscriptionCollectionsHandle = Meteor.subscribe 'my-collections' unless libraryMenuSubscriptionCollectionsHandle

Template.publicationLibraryMenuButtons.events
  'click .add-to-library': (e, template) ->
    return unless Meteor.personId()

    Meteor.call 'add-to-library', @_id, (error, count) =>
      return Notify.meteorError error, true if error

      Notify.success "Publication added to the library." if count

    return # Make sure CoffeeScript does not return anything

  'click .remove-from-library': (e, template) ->
    return unless Meteor.personId()

    Meteor.call 'remove-from-library', @_id, (error, count) =>
      return Notify.meteorError error, true if error

      Notify.success "Publication removed from the library." if count

    return # Make sure CoffeeScript does not return anything

Template.publicationLibraryMenuButtons.inLibrary = ->
  person = Meteor.person()
  return false unless person and @_id

  _.contains _.pluck(person.library, '_id'), @_id

Template.publicationLibraryMenuCollections.inLibrary = Template.publicationLibraryMenuButtons.inLibrary

Template.publicationLibraryMenuCollections.myCollections = ->
  return unless Meteor.personId()

  collections = Collection.documents.find
    'authorPerson._id': Meteor.personId()
  ,
    sort: [
      ['slug', 'asc']
    ]
  .fetch()

  # Because it is not possible to access parent data context from event handler, we map it
  # TODO: When will be possible to better access parent data context from event handler, we should use that
  _.map collections, (collection) =>
    collection._parent = @
    collection

Template.publicationLibraryMenuCollectionListing.inCollection = ->
  _.contains _.pluck(@publications, '_id'), @_parent._id

Template.publicationLibraryMenuCollectionListing.events
  'click .add-to-collection': (e, template) ->
    return unless Meteor.personId()

    collection = template.data

    Meteor.call 'add-to-library', @_parent._id, collection._id, (error, count) =>
      # TODO: Same operation is handled in client/library.coffee on drop. Sync both?
      return Notify.meteorError error, true if error

      Notify.success "Publication added to the collection." if count

    return # Make sure CoffeeScript does not return anything

  'click .remove-from-collection': (e, template) ->
    return unless Meteor.personId()

    collection = template.data

    Meteor.call 'remove-from-library', @_parent._id, collection._id, (error, count) =>
      return Notify.meteorError error, true if error

      Notify.success "Publication removed from the collection." if count

    return # Make sure CoffeeScript does not return anything

Template.publicationLibraryMenuCollectionListing.countDescription = Template.collectionListing.countDescription

Template.publicationDisplay.cached = ->
  publicationSubscribing() # To register dependency
  publicationHandle?.ready() and publicationCacheHandle?.ready() and Publication.documents.findOne(Session.get('currentPublicationId'), fields: cachedId: 1)?.cachedId

Template.publicationDisplay.created = ->
  @_displayHandle = null
  @_displayRendered = false

Template.publicationDisplay.rendered = ->
  return if @_displayRendered
  @_displayRendered = true

  Deps.nonreactive =>
    @_displayHandle = Deps.autorun =>
      publication = Publication.documents.findOne Session.get('currentPublicationId'), Publication.DISPLAY_FIELDS()

      return unless publication

      # Maybe we don't yet have whole publication object available
      try
        unless publication.url()
          return
      catch error
        return

      publication.show $(@findAll '.display-wrapper')
      Deps.onInvalidate publication.destroy

Template.publicationDisplay.destroyed = ->
  @_displayHandle.stop() if @_displayHandle
  @_displayHandle = null
  @_displayRendered = false

makePercentage = (x) ->
  100 * Math.max(Math.min(x, 1), 0)

# We do not have to use display wrapper position in computing viewport
# positions because we are just interested in how much display wrapper
# moved and scrollTop changes in sync with display wrapper moving.
# When scrollTop is 100px, 100px less of display wrapper is visible.

viewportTopPercentage = ->
  makePercentage($(window).scrollTop() / $('.viewer .display-wrapper').height())

viewportBottomPercentage = ->
  availableHeight = $(window).height() - $('header .container').height()
  scrollBottom = $(window).scrollTop() + availableHeight
  makePercentage(scrollBottom / $('.viewer .display-wrapper').height())

debouncedSetCurrentViewport = _.debounce (viewport) ->
  currentViewport.set viewport
,
  100

setViewportPosition = ($viewport) ->
  top = viewportTopPercentage()
  bottom = viewportBottomPercentage()
  $viewport.css
    top: "#{ top }%"
    # We are using top & height instead of top & bottom because
    # jQuery UI dragging is modifying only top and even if we
    # dynamically update bottom in drag or scroll event handlers,
    # height of the viewport still jitters as user drags. But the
    # the downside is that user cannot scroll pass the end of the
    # publication with scroller as jQuery UI stops dragging when
    # end reaches the edge of the containment. If we use top &
    # height we are dynamically making viewport smaller so this
    # is possible.
    height: "#{ bottom - top }%"

  displayHeight = $('.viewer .display-wrapper').height()
  debouncedSetCurrentViewport
    top: top * displayHeight / 100
    bottom: bottom * displayHeight / 100

scrollToOffset = (offset) ->
  # We round ourselves to make sure we are rounding in the same way accross all browsers.
  # Otherwise there is a conflict between what scroll to and how is the viewport then
  # positioned in the scroll event handler and what is the position of the viewport as we
  # are dragging it. This makes movement of the viewport not smooth.
  $(window).scrollTop Math.round(offset * $('.viewer .display-wrapper').height())

Template.publicationScroller.created = ->
  $(window).on 'scroll.publicationScroller resize.publicationScroller', (e) =>
    return unless publicationDOMReady()

    # We do not call setViewportPosition when dragging from scroll event
    # handler but directly from drag event handler because otherwise there
    # are two competing event handlers working on viewport position.
    # An example of the issue is if you drag fast with mouse below the
    # browser window edge if there are compething event handlers viewport
    # gets stuck and does not necessary go to the end position.
    setViewportPosition $(@findAll '.viewport') unless draggingViewport

    return # Make sure CoffeeScript does not return anything

Template.publicationScroller.rendered = ->
  # Dependency on publicationDOMReady value is registered because we
  # are using it in sections helper as well, which means that rendered will
  # be called multiple times as publicationDOMReady changes
  return unless publicationDOMReady()

  $viewport = $(@findAll '.viewport')

  draggingViewport = false
  $viewport.draggable
    containment: 'parent'
    axis: 'y'

    start: (e, ui) ->
      draggingViewport = true
      return # Make sure CoffeeScript does not return anything

    drag: (e, ui) ->
      $target = $(e.target)

      # It seems it is better to use $target.offset().top than ui.offset.top
      # because it seems to better represent real state of the viewport
      # position. A test is if you move fast the viewport to the end it
      # moves the publication exactly to the end of the last page and
      # not a bit before.
      viewportOffset = $target.offset().top - $target.parent().offset().top
      scrollToOffset viewportOffset / $target.parent().height()

      # Sync the position, especially the height. It can happen that user starts
      # dragging when viewport is smaller at the end of the page, when it get over
      # the publication end, so we want to enlarge the viewport to normal size when
      # user drags it up.
      setViewportPosition $(e.target)

      return # Make sure CoffeeScript does not return anything

    stop: (e, ui) ->
      draggingViewport = false
      return # Make sure CoffeeScript does not return anything

  setViewportPosition $viewport

Template.publicationScroller.destroyed = ->
  $(window).off '.publicationScroller'

Template.publicationScroller.sections = ->
  return [] unless publicationDOMReady()

  $displayWrapper = $('.viewer .display-wrapper')
  displayTop = $displayWrapper.outerOffset().top
  displayHeight = $displayWrapper.outerHeight(true)
  for section in $displayWrapper.children()
    $section = $(section)

    heightPercentage: 100 * $section.height() / displayHeight
    topPercentage: 100 * ($section.offset().top - displayTop) / displayHeight

Template.publicationScroller.events
  'click .scroller': (e, template) ->
    # We want to move only on clicks outside the viewport to prevent conflicts between dragging and clicking
    return if $(e.target).is('.viewport')

    $scroller = $(template.findAll '.scroller')
    clickOffset = e.pageY - $scroller.offset().top
    scrollToOffset (clickOffset - $(template.findAll '.viewport').height() / 2) / $scroller.height()

    return # Make sure CoffeeScript does not return anything

Template.highlightsControl.canEdit = ->
  # Only the author can edit for now
  return @author?._id is Meteor.personId()

Template.highlightsControl.events
  'click .delete': (e, template) ->
    Meteor.call 'remove-highlight', @_id, (error, count) =>
      Notify.meteorError error, true if error

    return # Make sure CoffeeScript does not return anything

  'mousedown .add-access, mouseup .add-access': (e, template) ->
    # A special case to prevent defocus after click on the input box
    e.stopPropagation()
    return # Make sure CoffeeScript does not return anything

  'focus .add-access': (e, template) ->
    $(template.firstNode).parents('.meta-menu').addClass('displayed')
    return # Make sure CoffeeScript does not return anything

  'blur .add-access': (e, template) ->
    $(template.firstNode).parents('.meta-menu').removeClass('displayed')
    $('.viewer .display-wrapper .highlights-layer .highlights-layer-highlight').trigger 'highlightControlBlur', [@_id]
    return # Make sure CoffeeScript does not return anything

Template.annotationsControl.events
  'click .add': (e, template) ->
    Meteor.call 'create-annotation', Session.get('currentPublicationId'), (error, annotationId) =>
      # TODO: Does Meteor triggers removal if insertion was unsuccessful, so that we do not have to do anything?
      return Notify.meteorError error, true if error

      focusAnnotationId = annotationId

      Meteor.Router.toNew Meteor.Router.annotationPath Session.get('currentPublicationId'), Session.get('currentPublicationSlug'), annotationId

    return # Make sure CoffeeScript does not return anything

resizeAnnotationsControl = ->
  padding = parseInt($('.annotations-control').css('right'))
  displayWrapper = $('.display-wrapper')
  left = displayWrapper.offset().left + displayWrapper.outerWidth() + padding
  $('.annotations-control').css
    left: left

Template.annotationsControl.rendered = ->
  resizeAnnotationsControl()

Template.publicationAnnotations.annotations = ->
  viewport = currentViewport()
  highlights = currentHighlights()

  insideViewport = (area) ->
    viewport.top <= area.top + area.height and viewport.bottom >= area.top

  visibleHighlights = _.uniq(highlightId for highlightId, boundingBoxes of highlights when _.some boundingBoxes, insideViewport)

  LocalAnnotation.documents.find
    $or: [
      # We display all annotations which are not linked to any highlight
      'references.highlights':
        $in: [null, []]
    ,
      # We display those which have a corresponding highlight visible
      'references.highlights._id':
        $in: visibleHighlights
    ,
      # We display the annotation editor
      local: true
      'author._id': Meteor.personId()
    ]
    'publication._id': Session.get 'currentPublicationId'
  ,
    sort:
      local: -1
      createdAt: 1

Template.publicationAnnotations.created = ->
  $(document).on 'mouseup.publicationAnnotations', (e) =>
    if Session.get 'currentHighlightId'
      # Highlight is currently selected, so we do not update location and
      # leave to Annotator.updateLocation to handle this. This allows making
      # one highlight immediatelly after another, without having to go through
      # a publication-only location after new highlight is created, befure
      # location is updated to this new highlight location.
      return

    # Left mouse button and mouseup happened on a target inside a display-page
    else if e.which is 1 and $(e.target).closest('.display-page').length and currentPublication?._highlighter?._annotator?._inAnyHighlight e.clientX, e.clientY
      # If mouseup happened inside a highlight, we leave location unchanged
      # so that we update location to the highlight location without going
      # through a publication-only location
      return

    # Left mouse button and mouseup happened on an annotation
    else if e.which is 1 and $(e.target).closest('.annotations-list .annotation').length
      # If mouseup happened inside an annotation, we leave location unchanged
      # so that we update location to the annotation location without going
      # through a publication-only location
      return

    else
      # Otherwise we deselect the annotation
      Meteor.Router.toNew Meteor.Router.publicationPath Session.get('currentPublicationId'), Session.get('currentPublicationSlug')

    return # Make sure CoffeeScript does not return anything

Template.publicationAnnotations.rendered = ->
  $annotations = $(@findAll '.annotations-list')

  $annotations.scrollLock()

  # We have to reset current left edge when re-rendering
  $annotations.css
    # To not crop the shadow of annotations we move the left edge
    # for 5px to the left and then add 5px (in fact 6px, so that
    # it looks better with our 1px shadow border) left margin to each
    # annotation. Same value is used in the _viewer.styl as well.
    left: $('.annotations-control').position().left - 5

  $annotations.find('.invite .body, .local .body').balanceText()

  # If we leave z-index constant for all meta menu items
  # then because of the DOM order those later in the DOM
  # are higher than earlier. But we want the opposite so
  # when meta menu opens down it goes over icons below.
  # This currently is a hack because this should be rendered
  # as part of Meteor rendering, but it does not yet support
  # indexing. See https://github.com/meteor/meteor/pull/912
  # TODO: Reimplement using Meteor indexing of rendered elements (@index)
  # We have to search for meta menus globally to have
  # access to other meta menus of other annotations
  $metaMenus = $annotations.find('.meta-menu')
  $metaMenus.each (i, metaMenu) =>
    $(metaMenu).css
      zIndex: $metaMenus.length - i

Template.publicationAnnotations.destroyed = ->
  $(document).off '.publicationAnnotations'

focusAnnotation = (body) ->
  return unless body

  if $(body).text().length > 0
    currentPublication?._highlighter?._annotator?._deselectAllHighlights()

    range = document.createRange()
    selection = window.getSelection()
    range.setStart body, 1
    range.collapse true
    selection.removeAllRanges()
    selection.addRange range

  body.focus()

focusEditor = ($editor) ->
  currentPublication?._highlighter?._annotator?._deselectAllHighlights()
  $editor.focus()

Template.publicationAnnotationsItem.events
  'click .edit-button': (e, template) ->
    e.preventDefault()

    LocalAnnotation.documents.update template.data._id,
      $set:
        editing: true

    return # Make sure CoffeeScript does not return anything

  'click .cancel-button': (e, template) ->
    e.preventDefault()

    LocalAnnotation.documents.update template.data._id,
      $unset:
        editing: ''

    return # Make sure CoffeeScript does not return anything

  # We do conversion of local annotation already in mousedown so that
  # we are before mousedown on document which deselects highlights
  'mousedown': (e, template) ->
    return

    ###
    TODO: Get rid of this. Annotation invites are being replaced.

    return unless @local

    LocalAnnotation.documents.update @_id,
      $unset:
        local: ''

    Meteor.Router.toNew Meteor.Router.annotationPath Session.get('currentPublicationId'), Session.get('currentPublicationSlug'), @_id

    # On click to convert local annotation we are for sure inside the annotation, so we can
    # immediatelly send a mouse enter event to make sure related highlight has a hovered state
    $('.viewer .display-wrapper .highlights-layer .highlights-layer-highlight').trigger 'annotationMouseenter', [@_id]

    return # Make sure CoffeeScript does not return anything
    ###

  'click': (e, template) ->
    # We do not select or even deselect an annotation on clicks inside a meta menu.
    # We do the former so that when user click "delete" button, an annotation below
    # is not automatically selected. We do the latter so that behavior is the same
    # as it is for highlights.
    if $(e.target).closest('.annotations-list .annotation .meta-menu').length
      Meteor.Router.toNew Meteor.Router.publicationPath Session.get('currentPublicationId'), Session.get('currentPublicationSlug')
    else
      Meteor.Router.toNew Meteor.Router.annotationPath Session.get('currentPublicationId'), Session.get('currentPublicationSlug'), @_id

    return # Make sure CoffeeScript does not return anything

Template.publicationAnnotationsItem.rendered = ->
  $annotation = $(@findAll '.annotation')

  # To make sure rendered can be called multiple times and we bind event handlers only once
  $annotation.off '.publicationAnnotationsItem'

  $annotation.on 'highlightMouseenter.publicationAnnotationsItem', (e, highlightId) =>
    $annotation.addClass('hovered') if highlightId in _.pluck @data.highlights, '_id'
    return # Make sure CoffeeScript does not return anything

  $annotation.on 'highlightMouseleave.publicationAnnotationsItem', (e, highlightId) =>
    $annotation.removeClass('hovered') if highlightId in _.pluck @data.highlights, '_id'
    return # Make sure CoffeeScript does not return anything

  $annotation.on 'mouseenter.publicationAnnotationsItem', (e) =>
    $('.viewer .display-wrapper .highlights-layer .highlights-layer-highlight').trigger 'annotationMouseenter', [@data._id]
    return # Make sure CoffeeScript does not return anything

  $annotation.on 'mouseleave.publicationAnnotationsItem', (e, highlightId) =>
    $('.viewer .display-wrapper .highlights-layer .highlights-layer-highlight').trigger 'annotationMouseleave', [@data._id]
    return # Make sure CoffeeScript does not return anything

  if focusAnnotationId is @data._id
    focusAnnotationId = null

    focusAnnotation $(@findAll '.body[contenteditable=true]').get(0)

Template.publicationAnnotationsItem.canEdit = Template.highlightsControl.canEdit

Template.publicationAnnotationsItem.selected = ->
  'selected' if @_id is Session.get 'currentAnnotationId'

Template.publicationAnnotationsItem.updatedFromNow = ->
  moment(@updatedAt).fromNow()

Template.annotationTags.rendered = ->
  # TODO: Make links work
  ###
  TODO: Temporary disabled, not yet finalized code

  $(@findAll '.annotation-tags-list').tagit
    readOnly: true
  ###

Template.annotationEditor.created = ->
  @_rendered = false

Template.annotationEditor.rendered = ->
  return if @_rendered
  @_rendered = true

  # Load Scribe
  @_scribe = new Scribe @find('.annotation-content-editor'),
    allowBlockElements: true

  @_scribe.use Scribe.plugins['blockquote-command']()
  @_scribe.use Scribe.plugins['link-prompt-command']()
  @_scribe.use Scribe.plugins['curly-quotes']()
  @_scribe.use Scribe.plugins['sanitizer']
    tags:
      p: {}
      br: {}
      b: {}
      i: {}
      blockquote: {}
      ol: {}
      ul: {}
      li: {}
      a:
        href: true

  ###
  TODO: Temporary disabled, not yet finalized code

  # Load tag-it
  $(@findAll '.annotation-tags-editor').tagit()

  # Create tags
  _.each @data.tags, (item) =>
    $(@findAll '.annotation-tags-editor').tagit 'createTag', item.tag?.name?.en
  ###

  return # Make sure CoffeeScript does not return anything

Template.annotationEditor.destroyed = ->
  @_rendered = false

Template.annotationEditor.events
  'click button.save': (e, template) ->
    $editor = $(template.findAll '.annotation-content-editor')

    # Prevent empty annotations
    return unless $editor.text().trim()

    body = $editor.html().trim()

    ###
    TODO: Temporary disabled, not yet finalized code

    $tags = $(template.findAll '.annotation-tags-editor')
    tags = _.map $tags.tagit('assignedTags'), (name) ->
      # TODO: Currently we have a race condition, use upsert
      existingTag = Tag.documents.findOne
        'name.en': name

      if existingTag?
        return tag: _.pick(existingTag, '_id')

      tagId = Tag.documents.insert
        name:
          en: name

      # return
      tag:
        _id: tagId
    ###

    if @local
      # TODO: Set privacy settings
      Meteor.call 'create-annotation', @publication._id, body, (error, annotationId) =>
        return Notify.meteorError error, true if error

        LocalAnnotation.documents.remove @_id

        focusAnnotationId = annotationId

        Meteor.Router.toNew Meteor.Router.annotationPath Session.get('currentPublicationId'), Session.get('currentPublicationSlug'), annotationId
    else
      Meteor.call 'update-annotation-body', @_id, body, (error, count) =>
        return Notify.meteorError error, true if error

        return unless count

        LocalAnnotation.documents.update @_id,
          $unset:
            editing: ''

        focusAnnotationId = @_id

        Meteor.Router.toNew Meteor.Router.annotationPath Session.get('currentPublicationId'), Session.get('currentPublicationSlug'), @_id

    return # Make sure CoffeeScript does not return anything

  'mouseup .annotation-content-editor': (e,template) ->
    return if template.data.editing

    LocalAnnotation.documents.update template.data._id,
      $set:
        editing: true

    focusEditor $(e.currentTarget)

    return # Make sure CoffeeScript does not return anything

  'input .annotation-content-editor': (e, template) ->
    $editor = $(e.currentTarget)

    if $editor.text()
      unless template.data.editing
        # Expand
        LocalAnnotation.documents.update template.data._id,
          $set:
            editing: true
    else
      if template.data.editing
        # Collapse
        LocalAnnotation.documents.update template.data._id,
          $unset:
            editing: ''

    return # Make sure CoffeeScript does not return anything

  'mousedown .format-buttons li': (e, template) ->
    e.preventDefault()

    # Port of scribe-plugin-toolbar
    # https://github.com/guardian/scribe-plugin-toolbar/blob/dist/scribe-plugin-toolbar.js
    command = template._scribe.getCommand $(e.currentTarget).data 'command-name'
    template._scribe.el.focus()
    command.execute()

    return # Make sure CoffeeScript does not return anything

  'keyup .format-buttons li': (e, template) ->
    updateScribeUI e, template
    return # Make sure CoffeeScript does not return anything

  'mouseup .format-buttons li': (e, template) ->
    updateScribeUI e, template
    return # Make sure CoffeeScript does not return anything

  'focus .format-buttons li': (e, template) ->
    updateScribeUI e, template
    return # Make sure CoffeeScript does not return anything

  'blur .format-buttons li': (e, template) ->
    updateScribeUI e, template
    return # Make sure CoffeeScript does not return anything

# Port of scribe-plugin-toolbar
# https://github.com/guardian/scribe-plugin-toolbar/blob/dist/scribe-plugin-toolbar.js
updateScribeUI = (e, template) ->
  $button = $(e.currentTarget)
  selection = new template._scribe.api.Selection()
  command = template._scribe.getCommand $button.data 'command-name'

  if selection.range and command.queryEnabled()
    $button.removeAttr 'disabled'

    if command.queryState()
      $button.addClass 'active'
    else
      $button.removeClass 'active'
  else
    $button.attr 'disabled', 'disabled'

  return # Make sure CoffeeScript does not return anything

Template.annotationCommentsList.comments = ->
  Comment.documents.find
    'annotation._id': @_id
  ,
    sort:
      createdAt: 1

Template.annotationCommentEditor.created = ->
  @_rendered = false

Template.annotationCommentEditor.rendered = ->
  $wrapper = $(@findAll '.comment-editor')
  $editor = $(@findAll '.comment-content-editor')

  if $editor.text() or $editor.is ':focus'
    $wrapper.addClass 'active'
  else
    $wrapper.removeClass 'active'

  # Run only once
  return if @_rendered
  @_rendered = true

  @_scribe = new Scribe @find('.comment-content-editor'),
    # No block elements, they would take up too much space
    allowBlockElements: false

  @_scribe.use Scribe.plugins['curly-quotes']()
  @_scribe.use Scribe.plugins['sanitizer']
    tags:
      br: {}
      b: {}
      i: {}
      a:
        href: true

Template.annotationCommentEditor.destroyed = ->
  @_rendered = false

Template.annotationCommentEditor.events
  'focus .comment-content-editor': (e, template) ->
    $wrapper = $(template.findAll '.comment-editor')
    $wrapper.addClass 'active'

    return # Make sure CoffeeScript does not return anything

  'input .comment-content-editor': (e, template) ->
    $editor = $(e.currentTarget)
    $wrapper = $(template.findAll '.comment-editor')

    if $editor.text()
      $wrapper.addClass 'active'

    return # Make sure CoffeeScript does not return anything

  'click button.comment': (e, template) ->
    $editor = $(template.findAll '.comment-content-editor')

    # Prevent empty comments
    return unless $editor.text().trim()

    body = $editor.html().trim()

    Meteor.call 'create-comment', template.data._id, body, (error, commentId) =>
      return Notify.meteorError error, true if error

      # Reset editor
      $editor.empty()

    return # Make sure CoffeeScript does not return anything

Template.annotationsControl.events
  'click .add-button': (e, template) ->
    e.preventDefault()

    LocalAnnotation.documents.update
      local: true
      'publication._id': Session.get 'currentPublicationId'
    ,
      $set:
        editing: true

    focusEditor $('.annotation.local .annotation-content-editor')

    # Scroll to new annotation editor and focus
    # TODO: Set cursor to the end
    $('.annotations-list').scrollTop 0

    return # Make sure CoffeeScript does not return anything

Template.annotationMetaMenu.events
  'click .delete': (e, template) ->
    Meteor.call 'remove-annotation', @_id, (error, count) =>
      # TODO: Does Meteor triggers removal if insertion was unsuccessful, so that we do not have to do anything?
      Notify.meteorError error, true if error

      return unless count

      Meteor.Router.toNew Meteor.Router.publicationPath Session.get('currentPublicationId'), Session.get('currentPublicationSlug')

    return # Make sure CoffeeScript does not return anything

Template.annotationMetaMenu.events addAccessEvents

Template.annotationMetaMenu.canEdit = Template.highlightsControl.canEdit

Template.contextMenu.events
  'change .access input:radio': (e, template) ->
    access = Annotation.ACCESS[$(template.findAll '.access input:radio:checked').val().toUpperCase()]

    defaults = getAnnoationDefaults()
    defaults.access = access
    Session.set 'annotationDefaults', defaults

    return # Make sure CoffeeScript does not return anything

  'mouseenter .access .selection': (e, template) ->
    accessHover = $(e.currentTarget).find('input').val()
    $(template.findAll '.access .displayed.description').removeClass('displayed')
    $(template.findAll ".access .description.#{ accessHover }").addClass('displayed')

    return # Make sure CoffeeScript does not return anything

  'mouseleave .access .selections': (e, template) ->
    accessHover = $(template.findAll '.access input:radio:checked').val()
    $(template.findAll '.access .displayed.description').removeClass('displayed')
    $(template.findAll ".access .description.#{ accessHover }").addClass('displayed')

    return # Make sure CoffeeScript does not return anything

Template.contextMenu.public = ->
  Session.get('annotationDefaults')?.access is Annotation.ACCESS.PUBLIC

Template.contextMenu.private = ->
  Session.get('annotationDefaults')?.access is Annotation.ACCESS.PRIVATE

Template.contextMenu.selectedGroups = ->
  Session.get('annotationDefaults')?.groups

Template.contextMenu.myGroups = Template.myGroups.myGroups

Template.contextMenuGroups.myGroups = Template.myGroups.myGroups

Template.contextMenuGroups.private = Template.contextMenu.private

Template.contextMenuGroups.selectedGroups = Template.contextMenu.selectedGroups

Template.contextMenuGroups.selectedGroupsDescription = ->
  defaults = Session.get('annotationDefaults')
  return unless defaults
  if defaults.groups.length is 1 then "1 group" else "#{ defaults.groups.length } groups"

Template.contextMenuGroups.events
  'click .add-to-working-in': (e, template) ->
    defaults = getAnnoationDefaults()
    defaults.groups = _.union defaults.groups, [@_id]
    Session.set 'annotationDefaults', defaults

    return # Make sure CoffeeScript does not return anything

  'click .remove-from-working-in': (e, template) ->
    defaults = getAnnoationDefaults()
    defaults.groups = _.without defaults.groups, @_id
    Session.set 'annotationDefaults', defaults

    return # Make sure CoffeeScript does not return anything

Template.contextMenuGroupListing.workingIn = ->
  defaults = Session.get('annotationDefaults')
  _.contains defaults?.groups, @_id

Template.footer.publicationDisplayed = ->
  'publication-displayed' unless Template.publication.loading() or Template.publication.notfound()
