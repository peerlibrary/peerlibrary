MAX_TEXT_LAYER_SEGMENTS_TO_RENDER = 100000

class @Page
  constructor: (@annotator, @pdfPage) ->
    @pageNumber = @pdfPage.pageNumber

    @textContent = null
    @textSegments = []
    @imageSegments = []
    @textSegmentsDone = null
    @imageLayerDone = null
    @highlightsEnabled = false
    @rendering = false

    @_extractedText = null

    @$displayPage = $("#display-page-#{ @pageNumber }")

  destroy: =>
    # Nothing really to do

  textLayer: =>
    textContentIndex = 0

    beginLayout: =>
      @textSegmentsDone = false

      textContentIndex = 0

    endLayout: =>
      @textSegmentsDone = true

      @_enableHighligts()

    appendText: (geom) =>
      segment = PDFJS.pdfTextSegment @textContent, textContentIndex, geom
      @textSegments.push segment if segment.hasWidth

      textContentIndex++

  imageLayer: =>
    beginLayout: =>
      @imageLayerDone = false

    endLayout: =>
      @imageLayerDone = true

      @_enableHighligts()

    appendImage: (geom) =>
      @imageSegments.push PDFJS.pdfImageSegment geom

  hasTextContent: =>
    @textContent isnt null

  extractText: =>
    return @_extractedText unless @_extractedText is null

    text = ''
    for t in @textContent.bidiTexts
      text += t.str

    # TODO: Clean-up the text: remove double whitespaces
    # TODO: Clean-up the text: remove hypenation

    @_extractedText = text

  # For debugging: draw divs for all segments
  _showSegments: =>
    divs = for segment in @textSegments
      $('<div/>').addClass('segment text-segment').css segment.boundingBox

    @$displayPage.append divs

    divs = for segment in @imageSegments
      $('<div/>').addClass('segment image-segment').css segment.boundingBox

    @$displayPage.append divs

  # For debugging: draw divs with text for all text segments
  _showTextSegments: =>
    divs = for segment in @textSegments
      $('<div/>').addClass('segment text-segment').css(segment.style).text(segment.text)

    @$displayPage.append divs

  _enableHighligts: =>
    return unless @textSegmentsDone and @imageLayerDone

    # Highlights already enabled for this page
    return if @highlightsEnabled
    @highlightsEnabled = true

    # For debugging
    #@_showSegments()
    #@_showTextSegments()

  render: =>
    assert @highlightsEnabled

    $textLayerDummy = @$displayPage.find('.text-layer-dummy')

    return unless $textLayerDummy.is(':visible')

    @rendering = true

    $textLayerDummy.hide()

    divs = for segment in @textSegments
      $('<div/>').addClass('text-layer-segment').css(segment.style).text(segment.text)

    # There is no use rendering so many divs to make browser useless
    # TODO: Report this to the server? Or should we simply discover such PDFs already on the server when processing them?
    @$displayPage.find('.text-layer').append divs if divs.length <= MAX_TEXT_LAYER_SEGMENTS_TO_RENDER

    @rendering = false

  remove: =>
    $textLayerDummy = @$displayPage.find('.text-layer-dummy')

    return if $textLayerDummy.is(':visible')

    @$displayPage.find('.text-layer').empty()

    $textLayerDummy.show()

class @Annotator
  constructor: ->
    @_pages = []

    $(window).on 'scroll.annotator', @checkRender
    $(window).on 'resize.annotator', @checkRender

  destroy: =>
    $(window).off 'scroll.annotator'
    $(window).off 'resize.annotator'

    page.destroy() for page in @_pages
    @_pages = []

  setPage: (pdfPage) =>
    # Initialize the page
    @_pages[pdfPage.pageNumber - 1] = new Page @, pdfPage

  setTextContent: (pageNumber, textContent) =>
    @_pages[pageNumber - 1].textContent = textContent

  hasTextContent: (pageNumber) =>
    @_pages[pageNumber - 1]?.hasTextContent()

  extractText: (pageNumber) =>
    @_pages[pageNumber - 1].extractText()

  textLayer: (pageNumber) =>
    @_pages[pageNumber - 1].textLayer()

  imageLayer: (pageNumber) =>
    @_pages[pageNumber - 1].imageLayer()

  checkRender: =>
    pagesToRender = []
    pagesToRemove = []

    for page in @_pages
      # If page is just in process of being rendered, we skip it
      continue if page.rendering

      # Page is not yet ready
      continue unless page.highlightsEnabled

      $canvas = page.$displayPage.find('canvas')

      canvasTop = $canvas.offset().top
      canvasBottom = canvasTop + $canvas.height()
      # Add 500px so that we start rendering early
      if canvasTop - 500 <= $(window).scrollTop() + $(window).height() and canvasBottom + 500 >= $(window).scrollTop()
        pagesToRender.push page
      else
        # TODO: Only if page is not having a user selection (multipage selection in progress)
        pagesToRemove.push page

    page.render() for page in pagesToRender
    page.remove() for page in pagesToRemove
