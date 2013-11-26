class @Page
  constructor: (@annotator, @pdfPage) ->
    @pageNumber = @pdfPage.pageNumber

    @textContent = null
    @textSegments = []
    @imageSegments = []
    @textSegmentsDone = null
    @imageLayerDone = null
    @highlightsEnabled = false

    @$displayPage = $("#display-page-#{ @pageNumber }")

  destroy: =>
    # Nothing really to do

  textLayer: =>
    beginLayout: =>
      @textSegmentsDone = false

    endLayout: =>
      @textSegmentsDone = true

      @_enableHighligts()

    appendText: (geom) =>
      @textSegments.push PDFJS.pdfTextSegment @textContent, @textSegments.length, geom

  imageLayer: =>
    beginLayout: =>
      @imageLayerDone = false

    endLayout: =>
      @imageLayerDone = true

      @_enableHighligts()

    appendImage: (geom) =>
      @imageSegments.push PDFJS.pdfImageSegment geom

  # For debugging: draw divs for all segments
  _showSegments: =>
    for segment in @textSegments
      @$displayPage.append(
        $('<div/>').addClass('segment text-segment').css segment.boundingBox
      )

    for segment in page.imageSegments
      @$displayPage.append(
        $('<div/>').addClass('segment image-segment').css segment.boundingBox
      )

  # For debugging: draw divs with text for all text segments
  _showTextSegments: =>
    for segment in @textSegments when segment.hasWidth
      @$displayPage.append(
        $('<div/>').addClass('segment text-segment').css(segment.style).text(segment.text)
      )

  _enableHighligts: =>
    return unless @textSegmentsDone and @imageLayerDone

    # Highlights already enabled for this page
    return if @highlightsEnabled
    @highlightsEnabled = true

    # For debugging
    #@_showSegments()
    #@_showTextSegments()

class @Annotator
  constructor: ->
    @_pages = []

  destroy: =>
    page.destroy() for page in @_pages

  setPage: (pdfPage) =>
    # Initialize the page
    @_pages[pdfPage.pageNumber - 1] = new Page @, pdfPage

  setTextContent: (pageNumber, textContent) =>
    @_pages[pageNumber - 1].textContent = textContent

  textLayer: (pageNumber) =>
    @_pages[pageNumber - 1].textLayer()

  imageLayer: (pageNumber) =>
    @_pages[pageNumber - 1].imageLayer()
