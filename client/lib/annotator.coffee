class @Annotator
  constructor: (@_publication) ->
    @_segments = []

  setPage: (page) =>
    # Initialize page
    @_segments[page.pageNumber - 1] =
      viewport: @_publication._viewport
        page: page # Dummy page object
      elements: []

  setTextContent: (pageNumber, textContent) =>
    @_segments[pageNumber - 1].textContent = textContent

  textLayer: (pageNumber) =>
    beginLayout: =>
      segments = @_segments[pageNumber - 1]
      segments.textLayerDone = false
      segments.textLayerCounter = 0

    endLayout: =>
      segments =  @_segments[pageNumber - 1]
      segments.textLayerDone = true

      console.log @_segments[pageNumber - 1].elements

    appendText: (geom) =>
      segments = @_segments[pageNumber - 1]
      segments.elements.push(
        PDFJS.pdfTextSegment segments.viewport.height, segments.textContent, segments.textLayerCounter, geom
      )
      segments.textLayerCounter++

  imageLayer: (pageNumber) =>
    beginLayout: =>
      @_segments[pageNumber - 1].imageLayerDone = false

    endLayout: =>
      @_segments[pageNumber - 1].imageLayerDone = true

    appendImage: (geom) =>
      #console.log pageNumber, "appendImage", geom
