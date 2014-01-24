draggingViewport = false

class @Publication extends @Publication
  constructor: (args...) ->
    super args...

    @_pages = null

  _viewport: (page) =>
    scale = 1.25
    page.page.getViewport scale

  _progressCallback: (progressData) =>
    # Maybe this instance has been destroyed in meantime
    return if @_pages is null

    @_progressData = progressData if progressData

    documentHalf = _.min [(@_progressData.loaded / @_progressData.total) / 2, 0.5]
    pagesHalf = if @_pdf then (@_pagesDone / @_pdf.numPages) / 2 else 0

    Session.set 'currentPublicationProgress', documentHalf + pagesHalf

  show: =>
    console.debug "Showing publication #{ @_id }"

    assert.strictEqual @_pages, null

    @_pagesDone = 0
    @_pages = []

    PDFJS.getDocument(@url(), null, null, @_progressCallback).then (@_pdf) =>
      # Maybe this instance has been destroyed in meantime
      return if @_pages is null

      # To make sure we are starting with empty slate
      $('.viewer .display-wrapper').empty()

      for pageNumber in [1..@_pdf.numPages]
        $canvas = $('<canvas/>').addClass('display-canvas').addClass('display-canvas-loading')
        $loading = $('<div/>').addClass('loading').text("Page #{ pageNumber }")
        $('<div/>').addClass('display-page').attr('id', "display-page-#{ pageNumber }").append($canvas).append($loading).appendTo('.viewer .display-wrapper')

        do (pageNumber) =>
          @_pdf.getPage(pageNumber).then (page) =>
            # Maybe this instance has been destroyed in meantime
            return if @_pages is null

            assert.equal pageNumber, page.pageNumber

            viewport = @_viewport
              page: page # Dummy page object

            $canvas = $("#display-page-#{ pageNumber } canvas")
            $canvas.removeClass('display-canvas-loading').attr
              height: viewport.height
              width: viewport.width

            # TODO: We currently change this based on the width of the last page, but pages might not be of same width, what can we do then?

            # We store current display wrapper width because we will later on
            # reposition annotations for the ammount display wrapper width changes
            displayWidth = parseFloat($('.viewer .display-wrapper').css('width'))
            $('footer.publication, .viewer .display-wrapper').css
              width: viewport.width
            # We reposition annotations if display wrapper width changed
            $('.annotations').css
              left: "+=#{ viewport.width - displayWidth }"

            @_pages[pageNumber - 1] =
              pageNumber: pageNumber
              page: page
              rendering: false
            @_pagesDone++

            @_progressCallback()

            # Check if new page should be maybe rendered?
            @checkRender()

            Session.set 'currentPublicationDOMReady', true if @_pagesDone is @_pdf.numPages

          , (args...) =>
            # TODO: Handle errors better (call destroy?)
            console.error "Error getting page #{ pageNumber }", args...

      $(window).on 'scroll.publication', @checkRender
      $(window).on 'resize.publication', @checkRender

    , (args...) =>
      # TODO: Handle errors better (call destroy?)
      console.error "Error showing #{ @_id }", args...

  checkRender: =>
    for page in @_pages or []
      continue if page.rendering

      $canvas = $("#display-page-#{ page.pageNumber } canvas")

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

    $(window).off 'scroll.publication'
    $(window).off 'resize.publication'

    for page in pages
      page.page.destroy()
    @_pdf.destroy() if @_pdf

    $('.viewer .display-wrapper').empty()

    Session.set 'currentPublicationDOMReady', false

  renderPage: (page) =>
    return if page.rendering
    page.rendering = true

    $canvas = $("#display-page-#{ page.pageNumber } canvas")

    # Redo canvas resize to make sure it is the right size
    # It seems sometimes already resized canvases are being deleted and replaced with initial versions
    viewport = @_viewport page
    $canvas.attr
      height: viewport.height
      width: viewport.width

    renderContext =
      canvasContext: $canvas.get(0).getContext '2d'
      viewport: @_viewport page

    console.debug "Rendering page #{ page.page.pageNumber }"

    page.page.render(renderContext).then =>
      # Maybe this instance has been destroyed in meantime
      return if @_pages is null

      console.debug "Rendering page #{ page.page.pageNumber } complete"

      $("#display-page-#{ page.pageNumber } .loading").hide()

    , (args...) =>
      # TODO: Handle errors better (call destroy?)
      console.error "Error rendering page #{ page.page.pageNumber }", args...

  # Fields needed when showing (rendering) the publication: those which are needed for PDF URL to be available and slug
  @SHOW_FIELDS: ->
    fields:
      foreignId: 1
      source: 1
      slug: 1

Deps.autorun ->
  if Session.get 'currentPublicationId'
    Meteor.subscribe 'publications-by-id', Session.get 'currentPublicationId'
    Meteor.subscribe 'annotations-by-publication', Session.get 'currentPublicationId'

Deps.autorun ->
  publication = Publications.findOne Session.get('currentPublicationId'), Publication.SHOW_FIELDS()

  return unless publication

  # currentPublicationSlug is null if slug is not present in URL, so we use
  # null when publication.slug is empty string to prevent infinite looping
  unless Session.equals 'currentPublicationSlug', (publication.slug or null)
    Meteor.Router.toNew Meteor.Router.publicationPath publication._id, publication.slug
    return

  # Maybe we don't yet have whole publication object available
  try
    unless publication.url()
      return
  catch e
    return

  publication.show()
  Deps.onInvalidate publication.destroy

Template.publication.publication = ->
  Publications.findOne Session.get 'currentPublicationId'

viewportHeightPercentage = ->
  100 * Math.min($(window).height() / $('.viewer .display-wrapper').height(), 1)

viewportPositionPercentage = ->
  $displayWrapper = $('.viewer .display-wrapper')
  100 * Math.max($(window).scrollTop() - $displayWrapper.offset().top, 0) / $displayWrapper.height()

scrollToOffset = (offset) ->
  $(window).scrollTop Math.round(offset * $('.viewer .display-wrapper').height() / $('.scroller').height())

Template.publicationScroller.created = ->
  $(window).on 'scroll.publicationScroller', (e) =>
    unless draggingViewport
      $(@find '.viewport').css 'top', "#{ viewportPositionPercentage() }%"

Template.publicationScroller.rendered = ->
  if Session.equals 'currentPublicationDOMReady', true
    $(@find '.viewport').draggable
      containment: 'parent'
      start: (e, ui) ->
        draggingViewport = true
        true # Ensure default runs
      drag: (e, ui) ->
        $target = $(e.target)
        scrollToOffset $target.offset().top - $target.parent().offset().top
        true # Ensure default runs
      stop: (e, ui) ->
        draggingViewport = false
        true # Ensure default runs
    $(@find '.viewport').height "#{ viewportHeightPercentage() }%"

Template.publicationScroller.destroyed = ->
  $(window).off 'scroll.publicationScroller'

Template.publicationScroller.sections = ->
  if Session.equals 'currentPublicationDOMReady', true
    $displayWrapper = $('.viewer .display-wrapper')
    totalHeight = $displayWrapper.height()
    for section in $displayWrapper.children()
      $section = $(section)

      heightPercentage: 100 * $section.height() / totalHeight
      topPercentage: 100 * $section.position().top / totalHeight

Template.publicationScroller.events
  'click': (e, template) ->
    $target = $(e.target)
    offset = if $target.is('.scroller') then e.offsetY - $('.scroller .viewport').height() / 2 else $target.offset().top - $target.parent().offset().top
    scrollToOffset offset

Template.publicationAnnotations.annotations = ->
  Annotations.find
    publication: Session.get 'currentPublicationId'
  ,
    sort: [
      ['location.page', 'asc']
      ['location.start', 'asc']
      ['location.end', 'asc']
    ]

Template.publicationAnnotationsItem.events =
  'mouseenter .annotation': (e, template) ->
    currentHighlight = true
    unless _.isEqual Session.get('currentHighlight'), @location
      Session.set 'currentHighlight', null
      currentHighlight = false

    showHighlight $('.viewer .display .display-text').eq(@location.page - 1), @location.start, @location.end, currentHighlight

    return # Make sure CoffeeScript does not return anything

  'mouseleave .annotation': (e, template) ->
    unless _.isEqual Session.get('currentHighlight'), @location
      hideHiglight $('.viewer .display .display-text')

    return # Make sure CoffeeScript does not return anything

  'click .annotation': (e, template) ->
    currentHighlight = true
    unless _.isEqual Session.get('currentHighlight'), @location
      Session.set 'currentHighlight', @location
      currentHighlight = false

    showHighlight $('.viewer .display .display-text').eq(@location.page - 1), @location.start, @location.end, currentHighlight

    return # Make sure CoffeeScript does not return anything

Template.publicationAnnotationsItem.highlighted = ->
  currentHighlight = Session.get 'currentHighlight'

  currentHighlight?.page is @location.page and currentHighlight?.start is @location.start and currentHighlight?.end is @location.end

Template.publicationAnnotationsItem.rendered = ->
  $(@findAll '.annotation').data
    annotation: @data
