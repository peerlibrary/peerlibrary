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
      @textSegments.push segment if segment.width

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

  _distance: (position, area) =>
    distanceXLeft = position.left - area.left
    distanceXRight = position.left - (area.left + area.width)

    distanceYTop = position.top - area.top
    distanceYBottom = position.top - (area.top + area.height)

    distanceX = if Math.abs(distanceXLeft) < Math.abs(distanceXRight) then distanceXLeft else distanceXRight
    if position.left > area.left and position.left < area.left + area.width
      distanceX = 0

    distanceY = if Math.abs(distanceYTop) < Math.abs(distanceYBottom) then distanceYTop else distanceYBottom
    if position.top > area.top and position.top < area.top + area.height
      distanceY = 0

    distanceX * distanceX + distanceY * distanceY

  _findClosestSegment: (position) =>
    closestSegmentIndex = -1
    closestDistance = Number.MAX_VALUE

    for segment, i in @textSegments
      distance = @_distance position, segment.boundingBox
      if distance < closestDistance
        closestSegmentIndex = i
        closestDistance = distance

    [closestSegmentIndex, Math.sqrt(closestDistance)]

  _findClosestSegmentFromEvent: (e) =>
    $canvas = @$displayPage.find('canvas')

    offset = $canvas.offset()
    left = e.pageX - offset.left
    top = e.pageY - offset.top
    @_findClosestSegment
      left: left
      top: top

  padTextSegment: (e) =>
    [closestSegmentIndex, closestDistance] = @_findClosestSegmentFromEvent e
    $closestSegmentDom = @textSegments[closestSegmentIndex].$domElement
    angle = @textSegments[closestSegmentIndex].angle
    scale = @textSegments[closestSegmentIndex].scale

    padding = closestDistance + 10

    # 2D vector rotation: http://www.siggraph.org/education/materials/HyperGraph/modeling/mod_tran/2drota.htm
    # x' = x cos(f) - y sin(f), y' = x sin(f) + y cos(f)
    # We scale x because we use scaling transformation along x-axis as well
    left = padding * (scale * Math.cos(angle) - Math.sin(angle))
    top = padding * (scale * Math.sin(angle) + Math.cos(angle))

    @$displayPage.find('.text-layer-segment').css
      padding: 0
      margin: 0
    $closestSegmentDom.css
      marginLeft: -left
      marginTop: -top
      padding: padding

  render: =>
    assert @highlightsEnabled

    $textLayerDummy = @$displayPage.find('.text-layer-dummy')

    return unless $textLayerDummy.is(':visible')

    @rendering = true

    $textLayerDummy.hide()

    divs = for segment in @textSegments
      segment.$domElement = $('<div/>').addClass('text-layer-segment').css(segment.style).text(segment.text)

    # There is no use rendering so many divs to make browser useless
    # TODO: Report this to the server? Or should we simply discover such PDFs already on the server when processing them?
    @$displayPage.find('.text-layer').append divs if divs.length <= MAX_TEXT_LAYER_SEGMENTS_TO_RENDER

    @$displayPage.on 'mousemove.annotator', @padTextSegment

    @rendering = false

  remove: =>
    assert not @rendering

    $textLayerDummy = @$displayPage.find('.text-layer-dummy')

    return if $textLayerDummy.is(':visible')

    @$displayPage.off 'mousemove.annotator'

    @$displayPage.find('.text-layer').empty()

    for segment in @textSegments
      segment.$domElement = null

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
