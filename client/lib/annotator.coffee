# TODO: We should really move pages into their own objects so that we do not have to pass pageNumber everywhere around

class @Annotator
  constructor: ->
    @_pages = []

  destroy: =>
    # Nothing really to do

  setPage: (page) =>
    # Initialize the page
    @_pages[page.pageNumber - 1] =
      page: page
      pageNumber: page.pageNumber
      textContent: null
      textSegments: []
      imageSegments: []
      textSegmentsDone: null
      imageLayerDone: null
      highlightsEnabled: false

  setTextContent: (pageNumber, textContent) =>
    @_pages[pageNumber - 1].textContent = textContent

  textLayer: (pageNumber) =>
    page = @_pages[pageNumber - 1]

    beginLayout: =>
      page.textSegmentsDone = false

    endLayout: =>
      page.textSegmentsDone = true

      @_enableHighligts pageNumber

    appendText: (geom) =>
      page.textSegments.push PDFJS.pdfTextSegment page.textContent, page.textSegments.length, geom

  imageLayer: (pageNumber) =>
    page = @_pages[pageNumber - 1]

    beginLayout: =>
      page.imageLayerDone = false

    endLayout: =>
      page.imageLayerDone = true

      @_enableHighligts pageNumber

    appendImage: (geom) =>
      page.imageSegments.push PDFJS.pdfImageSegment geom

  # For debugging: draw divs for all segments
  _showSegments: (pageNumber) =>
    page = @_pages[pageNumber - 1]
    $displayPage = $("#display-page-#{ pageNumber }")

    for segment in page.textSegments
      $displayPage.append(
        $('<div/>').addClass('segment text-segment').css segment.boundingBox
      )

    for segment in page.imageSegments
      $displayPage.append(
        $('<div/>').addClass('segment image-segment').css segment.boundingBox
      )

  # For debugging: draw divs with text for all text segments
  _showTextSegments: (pageNumber) =>
    page = @_pages[pageNumber - 1]
    $displayPage = $("#display-page-#{ pageNumber }")

    for segment in page.textSegments when segment.hasWidth
      $displayPage.append(
        $('<div/>').addClass('segment text-segment').css(segment.style).text(segment.text)
      )

  _enableHighligts: (pageNumber) =>
    page = @_pages[pageNumber - 1]

    return unless page.textSegmentsDone and page.imageLayerDone

    # Highlights already enabled for this page
    return if page.highlightsEnabled
    page.highlightsEnabled = true

    # For debugging
    #@_showSegments pageNumber
    #@_showTextSegments pageNumber
