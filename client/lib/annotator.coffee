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

  _distanceX: (position, area) =>
    return Number.POSITIVE_INFINITY unless area

    distanceXLeft = Math.abs(position.left - area.left)
    distanceXRight = Math.abs(position.left - (area.left + area.width))

    if position.left > area.left and position.left < area.left + area.width
      distanceX = 0
    else
      distanceX = Math.min(distanceXLeft, distanceXRight)

    distanceX

  _distanceY: (position, area) =>
    return Number.POSITIVE_INFINITY unless area

    distanceYTop = Math.abs(position.top - area.top)
    distanceYBottom = Math.abs(position.top - (area.top + area.height))

    if position.top > area.top and position.top < area.top + area.height
      distanceY = 0
    else
      distanceY = Math.min(distanceYTop, distanceYBottom)

    distanceY

  _distance: (position, area) =>
    return Number.POSITIVE_INFINITY unless area

    distanceX = @_distanceX position, area
    distanceY = @_distanceY position, area

    Math.sqrt(distanceX * distanceX + distanceY * distanceY)

  _eventToPosition: (e) =>
    $canvas = @$displayPage.find('canvas')

    offset = $canvas.offset()

    left: e.pageX - offset.left
    top: e.pageY - offset.top

  # Finds a text layer segment which is it to the left and up of the given position
  # and has highest index. Highest index means it is latest in the text flow of the
  # page. So we are searching for for latest text layer segment in text flow on the
  # page before the given position. Left and up is what is intuitively right for
  # text which flows left to right, top to bottom.
  _findLastLeftUpTextSegment: (position) =>
    segmentIndex = -1
    for segment, index in @textSegments
      # We allow few additional pixels so that position can be slightly to the left
      # of the text segment. This helps when user is with mouse between two columns
      # of text. With this the text segment to the right (in the right column) is
      # still selected when mouse is a bit to the left of the right column. Otherwise
      # selection would immediatelly jump the the left column. Good text editors put
      # this location when selection switches from right column to left column to the
      # middle between columns, but we do not really have information about the columns
      # so we at least make it a bit easier to the user. The only issue would be if
      # columns would be so close that those additional pixels would move into the left
      # column. This is unlikely if we keep the number small.
      segmentIndex = index if segment.boundingBox.left <= position.left + 10 * SCALE and segment.boundingBox.top <= position.top and index > segmentIndex

    segmentIndex

  # Simple search for closest text layer segment by euclidean distance
  _findClosestTextSegment: (position) =>
    closestSegmentIndex = -1
    closestDistance = Number.POSITIVE_INFINITY

    for segment, index in @textSegments
      distance = @_distance position, segment.boundingBox
      if distance < closestDistance
        closestSegmentIndex = index
        closestDistance = distance

    closestSegmentIndex

  # Pads a text layer segment (identified by index) so that its padding comes
  # under the position of the mouse. This makes text selection in browsers
  # behave like mouse is still over the text layer segment DOM element, even
  # when mouse is moved from it, for example, when dragging selection over empty
  # space in pages where there are no text layer segments.
  _padTextSegment: (position, index) =>
    segment = @textSegments[index]
    distance = @_distance position, segment.boundingBox
    $dom = segment.$domElement

    # Text layer segments can be rotated and scalled along x-axis
    angle = segment.angle
    scale = segment.scale

    # Padding is scaled later on, so we apply scaling inversely here so that it is
    # exact after scalling later on. Without that when scaling is < 1, when user moves
    # far away from the text segment, padding falls behind and does not reach mouse
    # position anymore.
    # Additionally, we add few pixels so that user can move mouse fast and still stay in.
    padding = distance / scale + 20 * SCALE

    # Padding (and text) rotation transformation is done through CSS and
    # we have to match it for margin, so we compute here margin under rotation.
    # 2D vector rotation: http://www.siggraph.org/education/materials/HyperGraph/modeling/mod_tran/2drota.htm
    # x' = x cos(f) - y sin(f), y' = x sin(f) + y cos(f)
    # Additionally, we use CSS scaling transformation along x-axis on padding
    # (and text), so we have to scale margin as well.
    left = padding * (scale * Math.cos(angle) - Math.sin(angle))
    top = padding * (scale * Math.sin(angle) + Math.cos(angle))

    @$displayPage.find('.text-layer-segment').css
      padding: 0
      margin: 0

    # To make code simpler, we apply padding all around the text segment DOM element,
    # but then we have to counteract text content position change by set negative
    # margin. With this, text content stays in place, but DOM element gets a
    # necessary padding.
    $dom.css
      marginLeft: -left
      marginTop: -top
      padding: padding

  padTextSegments: (e) =>
    position = @_eventToPosition e

    # Find latest text layer segment in text flow on the page before the given position
    segmentIndex = @_findLastLeftUpTextSegment position

    # segmentIndex might be -1, but @_distanceY returns
    # infinity in this case, so things work out
    if @_distanceY(position, @textSegments[segmentIndex]?.boundingBox) is 0
      # A clear case, we are directly over a segment y-wise. This means that
      # we are really directly over a segment, or that segment is to the right
      # of mouse position (because we searched for all segments to the left and
      # up of the position). In any case, this is the segment we want to pad.
      @_padTextSegment position, segmentIndex
      return

    # So we are close to the segment we want to pad, but we might currently have
    # a segment which is in the middle of the text line above our position, so we
    # search for the last text segment in that line, before it goes to the next
    # (our, where our position is) line.
    # On the other hand, segmentIndex might be -1 because we are on the left border
    # of the page and there are no text segments to the left and up. So we as well
    # do a search from the beginning of the page to the last text segment on the
    # text line just above our position.
    while @textSegments[segmentIndex + 1]
      if @textSegments[segmentIndex + 1].boundingBox.top + @textSegments[segmentIndex + 1].boundingBox.height > position.top
        break
      else
        segmentIndex++

    # segmentIndex can still be -1 if there are no text segments before
    # the mouse position, so let's simply find closest segment and pad that.
    # Not necessary for Chrome. There you can start selecting without being
    # over any text segment and it will correctly start when you move over
    # one. But in Firefox you have to start selecting over a text segment
    # (or padded text segment) to work correctly later on.
    segmentIndex = @_findClosestTextSegment position if segmentIndex is -1

    # segmentIndex can still be -1 if there are no text segments on
    # the page at all, then we do not have aynthing to do
    @_padTextSegment position, segmentIndex if segmentIndex isnt -1

    return # To prevent CoffeScript returning something

  render: =>
    assert @highlightsEnabled

    $textLayerDummy = @$displayPage.find('.text-layer-dummy')

    return unless $textLayerDummy.is(':visible')

    @rendering = true

    $textLayerDummy.hide()

    divs = for segment, index in @textSegments
      segment.$domElement = $('<div/>').addClass('text-layer-segment').css(segment.style).text(segment.text).data
        pageNumber: @pageNumber
        index: index

    # There is no use rendering so many divs to make browser useless
    # TODO: Report this to the server? Or should we simply discover such PDFs already on the server when processing them?
    @$displayPage.find('.text-layer').append divs if divs.length <= MAX_TEXT_LAYER_SEGMENTS_TO_RENDER

    @$displayPage.on 'mousemove.annotator', @padTextSegments

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
    @mouseDown = false

    $(window).on 'scroll.annotator', @checkRender
    $(window).on 'resize.annotator', @checkRender

    $(document).on 'mousedown.annotator', =>
      @mouseDown = true
      return # To prevent CoffeScript returning something
    $(document).on 'mouseup.annotator', =>
      @mouseDown = false
      return # To prevent CoffeScript returning something

  destroy: =>
    $(document).off 'mousedown.annotator'
    $(document).off 'mouseup.annotator'

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

    return # To prevent CoffeScript returning something