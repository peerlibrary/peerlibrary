class @Publication extends @Publication
  constructor: (args...) ->
    super args...

    @_pages = null
    @_annotator = new Annotator @

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
      $('#viewer .display-wrapper').empty()

      for pageNumber in [1..@_pdf.numPages]
        $canvas = $('<canvas/>').addClass('display-canvas').addClass('display-canvas-loading')
        $loading = $('<div/>').addClass('loading').text("Page #{ pageNumber }")
        $('<div/>').addClass('display-page').attr('id', "display-page-#{ pageNumber }").append($canvas).append($loading).appendTo('#viewer .display-wrapper')

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

            @_pages[pageNumber - 1] =
              pageNumber: pageNumber
              page: page
              rendering: false
            @_pagesDone++

            @_progressCallback()

            # Check if new page should be maybe rendered?
            @checkRender()

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

  destroy: =>
    console.debug "Destroying publication #{ @_id }"

    pages = @_pages or []
    @_pages = null # To remove references to pdf.js elements to allow cleanup, and as soon as possible as this disables other callbacks

    $(window).off 'scroll.publication'
    $(window).off 'resize.publication'

    for page in pages
      page.page.destroy()
    @_pdf.destroy() if @_pdf

  renderPage: (page) =>
    return if page.rendering
    page.rendering = true

    console.debug "Rendering page #{ page.page.pageNumber }"

    @_annotator.setPage page.page

    page.page.getTextContent().then (textContent) =>
      # Maybe this instance has been destroyed in meantime
      return if @_pages is null

      @_annotator.setTextContent page.pageNumber, textContent

      $canvas = $("#display-page-#{ page.pageNumber } canvas")

      # Redo canvas resize to make sure it is the right size
      # It seems sometimes already resized canvases are being deleted and replaced with initial versions
      viewport = @_viewport page
      $canvas.attr
        height: viewport.height
        width: viewport.width

      renderContext =
        canvasContext: $canvas.get(0).getContext '2d'
        textLayer: @_annotator.textLayer page.pageNumber
        imageLayer: @_annotator.imageLayer page.pageNumber
        viewport: @_viewport page

      page.page.render(renderContext).then =>
        # Maybe this instance has been destroyed in meantime
        return if @_pages is null

        console.debug "Rendering page #{ page.page.pageNumber } complete"

        $("#display-page-#{ page.pageNumber } .loading").hide()

      , (args...) =>
        # TODO: Handle errors better (call destroy?)
        console.error "Error rendering page #{ page.page.pageNumber }", args...

    , (args...) =>
      # TODO: Handle errors better (call destroy?)
      console.error "Error rendering page #{ page.page.pageNumber }", args...

  # Fields needed when showing (rendering) the publication: those which are needed for PDF URL to be available
  # TODO: Verify that it works after support for filtering fields on the client will be released in Meteor
  @SHOW_FIELDS: ->
    fields:
      foreignId: 1
      source: 1

Deps.autorun ->
  if Session.get 'currentPublicationId'
    Meteor.subscribe 'publications-by-id', Session.get 'currentPublicationId'
    Meteor.subscribe 'annotations-by-publication', Session.get 'currentPublicationId'

Deps.autorun ->
  # TODO: Limit only to fields necessary to display publication so that it is not rerun on field changes
  publication = Publications.findOne Session.get('currentPublicationId'), Publication.SHOW_FIELDS()

  return unless publication

  unless Session.equals 'currentPublicationSlug', publication.slug
    Meteor.Router.to Meteor.Router.publicationPath publication._id, publication.slug
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

    showHighlight $('#viewer .display .display-text').eq(@location.page - 1), @location.start, @location.end, currentHighlight

  'mouseleave .annotation': (e, template) ->
    unless _.isEqual Session.get('currentHighlight'), @location
      hideHiglight $('#viewer .display .display-text')

  'click .annotation': (e, template) ->
    currentHighlight = true
    unless _.isEqual Session.get('currentHighlight'), @location
      Session.set 'currentHighlight', @location
      currentHighlight = false

    showHighlight $('#viewer .display .display-text').eq(@location.page - 1), @location.start, @location.end, currentHighlight

Template.publicationAnnotationsItem.highlighted = ->
  currentHighlight = Session.get 'currentHighlight'

  currentHighlight?.page is @location.page and currentHighlight?.start is @location.start and currentHighlight?.end is @location.end

Template.publicationAnnotationsItem.rendered = ->
  $(@findAll '.annotation').data
    annotation: @data
