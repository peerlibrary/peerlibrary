class @Publication extends @Publication
  _viewport: (page) =>
    scale = 1.25
    page.page.getViewport scale

  _progressCallback: (progressData) =>
    @_progressData = progressData if progressData

    documentHalf = _.min [(@_progressData.loaded / @_progressData.total) / 2, 0.5]
    pagesHalf = if @_pdf then (@_pagesDone / @_pdf.numPages) / 2 else 0

    Session.set 'currentPublicationProgress', documentHalf + pagesHalf

  show: =>
    @destroy()

    @_pagesDone = 0
    @_pages = []

    # TODO: Handle errors as well
    PDFJS.getDocument(@url(), null, null, @_progressCallback).then (@_pdf) =>
      for pageNumber in [1..@_pdf.numPages]
        $canvas = $('<canvas/>').addClass('display-canvas')
        $pageDisplay = $('<div/>').addClass('display-page').append($canvas).appendTo('#viewer .display-wrapper')

        # TODO: Add pending page number + loading animation to the page

        do ($canvas, $pageDisplay) =>
          # TODO: Handle errors as well
          @_pdf.getPage(pageNumber).then (page) =>
            viewport = @_viewport
              page: page # Dummy page object

            $canvas.attr
              height: viewport.height
              width: viewport.width

            @_pages[page.pageNumber - 1] =
              $canvas: $canvas
              $pageDisplay: $pageDisplay
              page: page
              rendering: false
            @_pagesDone++

            @_progressCallback()

            # Check if new page should be maybe rendered?
            @checkRender()

    $(window).on 'scroll.publication', @checkRender

  checkRender: =>
    for page in @_pages
      continue if page.rendering

      canvasTop = page.$canvas.offset().top
      canvasBottom = canvasTop + page.$canvas.height()
      # Add 100px so that we start rendering early
      if canvasTop - 100 <= $(window).scrollTop() + $(window).height() and canvasBottom + 100 >= $(window).scrollTop()
        @renderPage page

  destroy: =>
    for page in @_pages or []
      page.page.destroy()
    @_pdf.destroy() if @_pdf
    @_pages = null # To remove references to canvas elements

    $(window).off 'scroll.publication'

  renderPage: (page) =>
    return if page.rendering
    page.rendering = true

    renderContext =
      canvasContext: page.$canvas.get(0).getContext '2d'
      viewport: @_viewport page

    console.debug "Rendering page #{ page.page.pageNumber }"

    # TODO: Handle errors as well
    page.page.render renderContext

Deps.autorun ->
  if Session.get 'currentPublicationId'
    Meteor.subscribe 'publications-by-id', Session.get 'currentPublicationId'
    Meteor.subscribe 'annotations-by-publication', Session.get 'currentPublicationId'

Deps.autorun ->
  publication = Publications.findOne Session.get 'currentPublicationId'

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
