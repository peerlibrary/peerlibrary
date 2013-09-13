class @Annotator
  constructor: (@_publication) ->
    @_pages = []

  setPage: (page) =>
    # Initialize the page
    @_pages[page.pageNumber - 1] =
      viewport: @_publication._viewport
        page: page # Dummy page object
      textSegments: []

  setTextContent: (pageNumber, textContent) =>
    @_pages[pageNumber - 1].textContent = textContent

  textLayer: (pageNumber) =>
    page = @_pages[pageNumber - 1]

    beginLayout: =>
      page.textSegmentsDone = false

    endLayout: =>
      page.textSegmentsDone = true

      console.log page.textSegments

    appendText: (geom) =>
      page.textSegments.push(
        PDFJS.pdfTextSegment page.viewport.height, page.textContent, page.textSegments.length, geom
      )

  imageLayer: (pageNumber) =>
    page = @_pages[pageNumber - 1]

    beginLayout: =>
      page.imageLayerDone = false

    endLayout: =>
      page.imageLayerDone = true

    appendImage: (geom) =>
      #console.log pageNumber, "appendImage", geom
