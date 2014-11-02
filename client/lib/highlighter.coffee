MAX_TEXT_LAYER_SEGMENTS_TO_RENDER = 100000

class Page
  constructor: (@highlighter, @viewport, @pdfPage) ->
    @pageNumber = @pdfPage.pageNumber

    @textContent = null
    @textSegments = []
    @imageSegments = []
    @textSegmentsDone = false
    @imageLayerDone = null
    @highlightsEnabled = false
    @rendering = false

    @_extractedText = null

    @$displayPage = $("#display-page-#{ @pageNumber }", @highlighter._$displayWrapper)

  destroy: =>
    # To release any cyclic memory
    @highlighter = null
    @pdfPage = null
    @$displayPage = null

  imageLayer: =>
    beginLayout: =>
      @imageLayerDone = false

    endLayout: =>
      @imageLayerDone = true

      @_enableHighlights()

    appendImage: (geom) =>
      @imageSegments.push PDFJS.pdfImageSegment geom

  hasTextContent: =>
    @textContent isnt null

  extractText: =>
    return @_extractedText unless @_extractedText is null

    @_extractedText = PDFJS.pdfExtractText @textContent

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

  _enableHighlights: =>
    return unless @textSegmentsDone and @imageLayerDone

    # Highlights already enabled for this page
    return if @highlightsEnabled
    @highlightsEnabled = true

    # For debugging
    #@_showSegments()
    #@_showTextSegments()

  _generateTextSegments: =>
    for geom in @textContent.items
      segment = PDFJS.pdfTextSegment @viewport, geom, @textContent.styles

      continue if segment.isWhitespace or not segment.hasArea

      @textSegments.push segment

    @_cleanTextSegments()

    @textSegmentsDone = true

  # TODO: A very specific fix which should be generalized, see https://github.com/peerlibrary/peerlibrary/issues/664
  _cleanTextSegments: =>
    # We traverse from the end and search for segments which should be before the first segment
    # and mark them unselectable. The rationale is that those segments which are spatially positioned
    # before the first segment, but are out-of-order in the array are watermarks or headers and other
    # elements not connected with the content, but they interfere with highlighting. It seems they are
    # simply appended at the end so we search them only near the end. We still allow unselectable
    # segments to be selected in the browser if user is directly over it.
    # See https://github.com/peerlibrary/peerlibrary/issues/387

    # Few segments can be correctly ordered among those at the end. For example, page numbers.
    threshold = 5 # segments, currently chosen completely arbitrary (just that it is larger than 1)
    for segment in @textSegments by -1
      if segment.boundingBox.left >= @textSegments[0].boundingBox.left and segment.boundingBox.top >= @textSegments[0].boundingBox.top
        threshold--
        break if threshold is 0
        continue
      segment.unselectable = true

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

  _eventToPosition: (event) =>
    $canvas = @$displayPage.find('canvas')

    offset = $canvas.offset()

    left: event.pageX - offset.left
    top: event.pageY - offset.top

  _overTextSegment: (position) =>
    segmentIndex = -1
    # We still want to allow unselectable segments to be selected in the
    # browser if user is directly over it, so we go over all segments here.
    for segment, index in @textSegments
      if @_distanceX(position, segment.boundingBox) + @_distanceY(position, segment.boundingBox) is 0
        segmentIndex = index
        break

    segmentIndex

  # Finds a text layer segment which is it to the left and up of the given position
  # and has highest index. Highest index means it is latest in the text flow of the
  # page. So we are searching for for latest text layer segment in text flow on the
  # page before the given position. Left and up is what is intuitively right for
  # text which flows left to right, top to bottom.
  _findLastLeftUpTextSegment: (position) =>
    segmentIndex = -1
    for segment, index in @textSegments when not segment.unselectable
      # We allow few additional pixels so that position can be slightly to the left
      # of the text segment. This helps when user is with mouse between two columns
      # of text. With this the text segment to the right (in the right column) is
      # still selected when mouse is a bit to the left of the right column. Otherwise
      # selection would immediately jump the the left column. Good text editors put
      # this location when selection switches from right column to left column to the
      # middle between columns, but we do not really have information about the columns
      # so we at least make it a bit easier to the user. The only issue would be if
      # columns would be so close that those additional pixels would move into the left
      # column. This is unlikely if we keep the number small.
      segmentIndex = index if segment.boundingBox.left <= position.left + 10 * @viewport.scale and segment.boundingBox.top <= position.top and index > segmentIndex

    segmentIndex

  # Simple search for closest text layer segment by euclidean distance
  _findClosestTextSegment: (position) =>
    closestSegmentIndex = -1
    closestDistance = Number.POSITIVE_INFINITY

    for segment, index in @textSegments when not segment.unselectable
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

    # Text layer segments can be rotated and scaled along x-axis
    angle = segment.angle
    scaleX = segment.scaleX

    # Padding is scaled later on, so we apply scaling inversely here so that it is
    # exact after scaling later on. Without that when scaling is < 1, when user moves
    # far away from the text segment, padding falls behind and does not reach mouse
    # position anymore.
    # Additionally, we add few pixels so that user can move mouse fast and still stay in.
    padding = distance / scaleX + 20 * @viewport.scale

    # Padding (and text) rotation transformation is done through CSS and
    # we have to match it for margin, so we compute here margin under rotation.
    # 2D vector rotation: http://www.siggraph.org/education/materials/HyperGraph/modeling/mod_tran/2drota.htm
    # x' = x cos(f) - y sin(f), y' = x sin(f) + y cos(f)
    # Additionally, we use CSS scaling transformation along x-axis on padding
    # (and text), so we have to scale margin as well.
    left = padding * (scaleX * Math.cos(angle) - Math.sin(angle))
    top = padding * (scaleX * Math.sin(angle) + Math.cos(angle))

    @$displayPage.find('.text-layer-segment').css
      padding: 0
      margin: 0

    # Optimization if position is to the right and down of the segment. We do this
    # because modifying both margin and padding slightly jitters text segment around
    # because of rounding to pixel coordinates (text is scaled and rotated so margin
    # and padding values do not fall nicely onto pixel coordinates).
    if segment.boundingBox.left <= position.left and segment.boundingBox.top <= position.top
      $dom.css
        paddingRight: padding
        paddingBottom: padding
      return

    # Otherwise we apply padding all around the text segment DOM element and do not
    # really care where the mouse position is, we have to change both margin and
    # padding anyway.
    # We counteract text content position change introduced by padding by setting
    # negative margin. With this, text content stays in place, but DOM element gets a
    # necessary padding.
    $dom.css
      marginLeft: -left
      marginTop: -top
      padding: padding

  padTextSegments: (event) =>
    position = @_eventToPosition event

    # First check if we are directly above a text segment. We could combine this
    # with _findLastLeftUpTextSegment below, but we also want to handle the case
    # when we are directly above an unselectable segment.
    segmentIndex = @_overTextSegment position

    if segmentIndex isnt -1
      @_padTextSegment position, segmentIndex
      return

    # Find latest text layer segment in text flow on the page before the given position
    segmentIndex = @_findLastLeftUpTextSegment position

    # segmentIndex might be -1, but @_distanceY returns
    # infinity in this case, so things work out
    if @_distanceY(position, @textSegments[segmentIndex]?.boundingBox) is 0
      # A clear case, we are directly over a segment y-wise. This means that
      # segment is to the left of mouse position (because we searched for
      # all segments to the left and up of the position and we already checked
      # if we are directly over a segment). This is the segment we want to pad.
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
    # We keep track of the number of skipped unselectable segments to not increase
    # segmentIndex until we get to a selectable segment again (if we do at all).
    skippedUnselectable = 0
    while @textSegments[segmentIndex + skippedUnselectable + 1]
      segment = @textSegments[segmentIndex + skippedUnselectable + 1]
      if segment.unselectable
        skippedUnselectable++
      else
        segmentIndex += skippedUnselectable
        skippedUnselectable = 0
        if segment.boundingBox.top + segment.boundingBox.height > position.top
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

    return # Make sure CoffeeScript does not return anything

  isRendered: =>
    return false unless @highlightsEnabled

    return false if @rendering

    not @$displayPage.find('.text-layer-dummy').is(':visible')

  render: =>
    assert @highlightsEnabled

    $textLayerDummy = @$displayPage.find('.text-layer-dummy')

    return unless $textLayerDummy.is(':visible')

    return if @rendering
    @rendering = true

    $textLayerDummy.hide()

    divs = for segment, index in @textSegments
      segment.$domElement = $('<div/>').addClass('text-layer-segment').css(segment.style).text(segment.text).data
        pageNumber: @pageNumber
        index: index

    # There is no use rendering so many divs to make browser useless
    # TODO: Report this to the server? Or should we simply discover such PDFs already on the server when processing them?
    @$displayPage.find('.text-layer').append divs if divs.length <= MAX_TEXT_LAYER_SEGMENTS_TO_RENDER

    @$displayPage.on 'mousemove.highlighter', @padTextSegments

    @rendering = false

    @highlighter.pageRendered @

  remove: =>
    assert not @rendering

    $textLayerDummy = @$displayPage.find('.text-layer-dummy')

    return if $textLayerDummy.is(':visible')

    @$displayPage.off 'mousemove.highlighter'

    @$displayPage.find('.text-layer').empty()

    for segment in @textSegments
      segment.$domElement = null

    $textLayerDummy.show()

    @highlighter.pageRemoved @

class @Highlighter
  constructor: (@_$displayWrapper, isPdf) ->
    @_pages = []
    @_numPages = null
    @mouseDown = false

    @_highlightsHandle = null
    @_highlightLocationHandle = null

    @_annotator = new Annotator @, @_$displayWrapper

    @_annotator.addPlugin 'CanvasTextHighlights'
    @_annotator.addPlugin 'DomTextMapper'
    @_annotator.addPlugin 'TextAnchors'
    @_annotator.addPlugin 'TextRange'
    @_annotator.addPlugin 'TextPosition'
    @_annotator.addPlugin 'TextQuote'
    @_annotator.addPlugin 'DOMAnchors'

    @_annotator.addPlugin 'PeerLibraryPDF' if isPdf

    # Annotator.TextPositionAnchor does not seem to be set globally from the
    # TextPosition's pluginInit, so let's do it here again
    # TODO: Can this be fixed somehow?
    Annotator.TextPositionAnchor = @_annotator.plugins.TextPosition.Annotator.TextPositionAnchor

    $(window).on 'scroll.highlighter resize.highlighter', @checkRender if isPdf

  destroy: =>
    $(window).off '.highlighter'

    # We stop handles here and not just leave it to Tracker.autorun to do it to cleanup in the right order
    @_highlightsHandle?.stop()
    @_highlightsHandle = null
    @_highlightLocationHandle?.stop()
    @_highlightLocationHandle = null

    page.destroy() for page in @_pages
    @_pages = []
    @_numPages = null # To disable any asynchronous _checkHighlighting
    @_annotator.destroy() if @_annotator
    @_annotator = null # To release any cyclic memory
    @_$displayWrapper = null # To release any cyclic memory

  setNumPages: (@_numPages) =>

  getNumPages: =>
    @_numPages

  setPage: (viewport, pdfPage) =>
    # Initialize the page
    @_pages[pdfPage.pageNumber - 1] = new Page @, viewport, pdfPage

  setTextContent: (pageNumber, textContent) =>
    @_pages[pageNumber - 1].textContent = textContent

    @_pages[pageNumber - 1]._generateTextSegments()

    @_checkHighlighting()

  hasTextContent: (pageNumber) =>
    @_pages[pageNumber - 1]?.hasTextContent()

  getTextLayer: (pageNumber) =>
    @_pages[pageNumber - 1].$displayPage.find('.text-layer').get(0)

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

    return # Make sure CoffeeScript does not return anything

  isPageRendered: (pageNumber) =>
    @_pages[pageNumber - 1]?.isRendered()

  _checkHighlighting: =>
    return unless @_pages.length is @_numPages

    return unless _.every @_pages, (page) -> page.hasTextContent()

    @_annotator._scan()

    @_highlightsHandle = Highlight.documents.find(
      'publication._id': Session.get 'currentPublicationId'
    ).observeChanges
      added: (id, fields) =>
        @highlightAdded id, fields
      changed: (id, fields) =>
        @highlightChanged id, fields
      removed: (id) =>
        @highlightRemoved id

    @_highlightLocationHandle = Tracker.autorun =>
      @_annotator._selectHighlight Session.get 'currentHighlightId'

  pageRendered: (page) =>
    # We update the mapper for new page
    @_annotator?.domMapper?.pageRendered page.pageNumber

  pageRemoved: (page) =>
    # We update the mapper for removed page
    @_annotator?.domMapper?.pageRemoved page.pageNumber

  highlightAdded: (id, fields) =>
    if @_annotator.hasAnnotation id
      @highlightChanged id, fields
    else
      @_annotator._highlightAdded id, fields

  highlightChanged: (id, fields) =>
    @_annotator._highlightChanged id, fields

  highlightRemoved: (id) =>
    @_annotator._highlightRemoved id
