@SCALE = 1.25

draggingViewport = false

# Should not be used directly but through isPublicationDOMReady and setPublicationDOMReady
_publicationDOMReady = false

# We use our own dependency tracking for publicationDOMReady and not Session to
# make sure it is not preserved when site autoreloads (because of a code change).
# Otherwise publicationDOMReady stored in Session would be restored to true which
# would be an invalid initial state. But on the other hand we want it to be
# a reactive value so that we can combine code logic easy.
publicationDOMReadyDependency = new Deps.Dependency()

isPublicationDOMReady = ->
  publicationDOMReadyDependency.depend()
  _publicationDOMReady

setPublicationDOMReady = (ready) ->
  return if _publicationDOMReady is ready

  _publicationDOMReady = ready
  publicationDOMReadyDependency.changed()

class @Publication extends @Publication
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
    console.debug "Showing publication #{ @_id }"

    assert.strictEqual @_pages, null

    @_pagesDone = 0
    @_pages = []
    @_highlighter = new Highlighter @_$displayWrapper

    PDFJS.getDocument(@url(), null, null, @_progressCallback).then (@_pdf) =>
      # Maybe this instance has been destroyed in meantime
      return if @_pages is null

      # To make sure we are starting with empty slate
      @_$displayWrapper.empty()
      setPublicationDOMReady false

      @_highlighter.setNumPages @_pdf.numPages

      for pageNumber in [1..@_pdf.numPages]
        $displayCanvas = $('<canvas/>').addClass('display-canvas').addClass('display-canvas-loading').data('page-number', pageNumber)
        $highlightsCanvas = $('<canvas/>').addClass('highlights-canvas')
        $highlightsLayer = $('<div/>').addClass('highlights-layer')
        # We enable forwarding of mouse events from text layer to highlights layer
        $textLayer = $('<div/>').addClass('text-layer').forwardMouseEvents()
        $highlightsControl = $('<div/>').addClass('highlights-control').append(
          $('<div/>').addClass('meta-menu').append(
            $('<i/>').addClass('icon-menu'),
            $('<div/>').addClass('meta-content'),
          )
        )
        $loading = $('<div/>').addClass('loading').text("Page #{ pageNumber }")

        $('<div/>').addClass(
          'display-page'
        ).attr(
          id: "display-page-#{ pageNumber }"
        ).append(
          $displayCanvas,
          $highlightsCanvas,
          $highlightsLayer,
          $textLayer,
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

            $displayPage = $("#display-page-#{ pdfPage.pageNumber }", @_$displayWrapper)
            $canvas = $displayPage.find('canvas') # Both display and highlights canvases
            $canvas.removeClass('display-canvas-loading').attr
              height: viewport.height
              width: viewport.width
            $displayPage.css
              height: viewport.height
              width: viewport.width

            # TODO: We currently change this based on the width of the last page, but pages might not be of same width, what can we do then?

            # We store current display wrapper width because we will later on
            # reposition annotations for the ammount display wrapper width changes
            displayWidth = @_$displayWrapper.width()
            # We remove all added CSS in publication destroy
            $('footer.publication').add(@_$displayWrapper).css
              width: viewport.width
            # We reposition annotations if display wrapper width changed
            $('.annotations-control, .annotations').css
              left: "+=#{ viewport.width - displayWidth }"

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

            setPublicationDOMReady true if @_pagesDone is @_pdf.numPages

          , (args...) =>
            # TODO: Handle errors better (call destroy?)
            console.error "Error getting page #{ pageNumber }", args...

      $(window).on 'scroll.publication resize.publication', @checkRender

    , (args...) =>
      # TODO: Handle errors better (call destroy?)
      console.error "Error showing #{ @_id }", args...

  _getTextContent: (pdfPage) =>
    console.debug "Getting text content for page #{ pdfPage.pageNumber }"

    pdfPage.getTextContent().then (textContent) =>
      # Maybe this instance has been destroyed in meantime
      return if @_pages is null

      @_highlighter.setTextContent pdfPage.pageNumber, textContent

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

      console.debug "Getting text content for page #{ pdfPage.pageNumber } complete"

      # Check if the page should be maybe rendered, but we
      # skipped it because text content was not yet available
      @checkRender()

    , (args...) =>
      # TODO: Handle errors better (call destroy?)
      console.error "Error getting text content for page #{ pdfPage.pageNumber }", args...

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
    console.debug "Destroying publication #{ @_id }"

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
    $('.annotations-control, .annotations').css
      left: ''

    @_$displayWrapper = null

    setPublicationDOMReady false

  renderPage: (page) =>
    return if page.rendering
    page.rendering = true

    console.debug "Rendering page #{ page.pdfPage.pageNumber }"

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

      console.debug "Rendering page #{ page.pdfPage.pageNumber } complete"

      $("#display-page-#{ page.pageNumber } .loading", @_$displayWrapper).hide()

      # Maybe we have to render text layer as well
      @_highlighter.checkRender()

    , (args...) =>
      # TODO: Handle errors better (call destroy?)
      console.error "Error rendering page #{ page.pdfPage.pageNumber }", args...

  # Fields needed when displaying (rendering) the publication: those which are needed for PDF URL to be available
  @DISPLAY_FIELDS: ->
    fields:
      foreignId: 1
      source: 1

Deps.autorun ->
  if Session.get 'currentPublicationId'
    Meteor.subscribe 'publications-by-id', Session.get 'currentPublicationId'
    Meteor.subscribe 'highlights-by-publication', Session.get 'currentPublicationId'
    Meteor.subscribe 'annotations-by-publication', Session.get 'currentPublicationId'

Deps.autorun ->
  publication = Publications.findOne Session.get('currentPublicationId'),
    fields:
      _id: 1
      slug: 1

  return unless publication

  # currentPublicationSlug is null if slug is not present in location, so we use
  # null when publication.slug is empty string to prevent infinite looping
  return if Session.equals 'currentPublicationSlug', (publication.slug or null)

  highlightId = Session.get 'currentHighlightId'
  if highlightId
    Meteor.Router.toNew Meteor.Router.highlightPath publication._id, publication.slug, highlightId
  else
    Meteor.Router.toNew Meteor.Router.publicationPath publication._id, publication.slug

Template.publicationMetaMenu.publication = ->
  Publications.findOne Session.get 'currentPublicationId'

Template.publicationDisplay.created = ->
  @_displayHandle = null
  @_displayRendered = false

Template.publicationDisplay.rendered = ->
  return if @_displayRendered
  @_displayRendered = true

  Deps.nonreactive =>
    @_displayHandle = Deps.autorun =>
      publication = Publications.findOne Session.get('currentPublicationId'), Publication.DISPLAY_FIELDS()

      return unless publication

      # Maybe we don't yet have whole publication object available
      try
        unless publication.url()
          return
      catch e
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

scrollToOffset = (offset) ->
  # We round ourselves to make sure we are rounding in the same way accross all browsers.
  # Otherwise there is a conflict between what scroll to and how is the viewport then
  # positioned in the scroll event handler and what is the position of the viewport as we
  # are dragging it. This makes movement of the viewport not smooth.
  $(window).scrollTop Math.round(offset * $('.viewer .display-wrapper').height())

Template.publicationScroller.created = ->
  $(window).on 'scroll.publicationScroller', (e) =>
    return unless isPublicationDOMReady()

    # We do not call setViewportPosition when dragging from scroll event
    # handler but directly from drag event handler because otherwise there
    # are two competing event handlers working on viewport position.
    # An example of the issue is if you drag fast with mouse below the
    # browser window edge if there are compething event handlers viewport
    # gets stuck and does not necessary go to the end position.
    setViewportPosition $(@findAll '.viewport') unless draggingViewport

Template.publicationScroller.rendered = ->
  # Dependency on isPublicationDOMReady value is registered because we
  # are using it in sections helper as well, which means that rendered will
  # be called multiple times as isPublicationDOMReady changes
  return unless isPublicationDOMReady()

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
  return [] unless isPublicationDOMReady()

  $displayWrapper = $('.viewer .display-wrapper')
  displayTop = $displayWrapper.offset().top
  displayHeight = $displayWrapper.height()
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

Template.annotationsControl.events
  'click .add': (e, template) =>
    annotation =
      author:
        _id: Meteor.personId()
      publication:
        _id: Session.get 'currentPublicationId'
      local: true

    LocalAnnotations.insert annotation, (error, id) =>
      # Meteor triggers removal if insertion was unsuccessful, so we do not have to do anything
      throw error if error

Template.publicationAnnotations.annotations = ->
  LocalAnnotations.find
    'publication._id': Session.get 'currentPublicationId'

Template.publicationAnnotations.rendered = ->
  $(@findAll '.annotations').scrollLock()
