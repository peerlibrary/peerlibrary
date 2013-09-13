class @Annotator
  constructor: ->
    @_pages = []

  setPage: (page) =>
    # Initialize the page
    @_pages[page.pageNumber - 1] =
      textSegments: []
      imageSegments: []
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

      @_showSegments pageNumber

    appendText: (geom) =>
      page.textSegments.push(
        PDFJS.pdfTextSegment page.textContent, page.textSegments.length, geom
      )

  imageLayer: (pageNumber) =>
    page = @_pages[pageNumber - 1]

    beginLayout: =>
      page.imageLayerDone = false

    endLayout: =>
      page.imageLayerDone = true

      @_enableHighligts pageNumber

    appendImage: (geom) =>
      # TODO: Add image segments
      #console.log pageNumber, "appendImage", geom

  # For debugging: draw divs for all segments
  _showSegments: (pageNumber) =>
    page = @_pages[pageNumber - 1]
    $displayPage = $("#display-page-#{ pageNumber }")

    for segment in page.textSegments
      $displayPage.append(
        $('<div/>').addClass('segment text-segment').css
          left: segment.left
          top: segment.top
          width: segment.width
          height: segment.height
      )

    # TODO: Display image segments as well

  _findClosestSegment: (pageNumber, position) =>
    page = @_pages[pageNumber - 1]

    closestDistance = Number.MAX_VALUE
    closestSegmentIndex = -1

    for segment, i in page.textSegments
      distanceXLeft = position.left - segment.left
      distanceXRight = position.left - (segment.left + segment.width)

      distanceYTop = position.top - segment.top
      distanceYBottom = position.top - (segment.top + segment.height)

      distanceX = if Math.abs(distanceXLeft) < Math.abs(distanceXRight) then distanceXLeft else distanceXRight
      if position.left > segment.left and position.left < segment.left + segment.width
        distanceX = 0

      distanceY = if Math.abs(distanceYTop) < Math.abs(distanceYBottom) then distanceYTop else distanceYBottom
      if position.top > segment.top and position.top < segment.top + segment.height
        distanceY = 0

      distance = distanceX * distanceX + distanceY * distanceY
      if distance < closestDistance
        closestDistance = distance
        closestSegmentIndex = i

    closestSegmentIndex

  _showHighlight: (pageNumber, start, end) =>

  _openHighlight: (pageNumber, highlightStartIndex, highlightEndIndex) =>

  _closeHighlight: (pageNumber) =>

  _enableHighligts: (pageNumber) =>
    page = @_pages[pageNumber - 1]

    return unless page.textSegmentsDone and page.imageLayerDone

    # Highlights already enabled for this page
    return if page.highlightsEnabled
    page.highlightsEnabled = true

    $canvas = $("#display-page-#{ pageNumber } canvas")

    highlightStartPosition = null
    highlightStartIndex = -1
    highlightEndIndex = -1

    $canvas.mousemove (e) =>
      return if highlightStartIndex is -1

      offset = $canvas.offset()
      highlightEndIndex = @_findClosestSegment pageNumber,
        left: e.pageX - offset.left
        top: e.pageY - offset.top

      return if highlightEndIndex is -1

      @_showHighlight pageNumber, highlightStartIndex, highlightEndIndex

    $canvas.mousedown (e) =>
      offset = $canvas.offset()
      highlightStartPosition =
        left: e.pageX - offset.left
        top: e.pageY - offset.top
      highlightStartIndex = @_findClosestSegment pageNumber, highlightStartPosition

    $canvas.mouseup (e) =>
      return if highlightStartIndex is -1

      offset = $canvas.offset()
      if highlightStartPosition.left is e.pageX - offset.left and highlightStartPosition.top is e.pageY - offset.top
        # Mouse went up at the same location that it started, we just cleanup
        @_closeHighlight pageNumber
      else
        @_openHighlight pageNumber, highlightStartIndex, highlightEndIndex

      highlightStartPosition = null
      highlightStartIndex = -1
      highlightEndIndex = -1

    $canvas.mouseleave (e) =>
      return if highlightStartIndex is -1

      @_closeHighlight pageNumber

      highlightStartPosition = null
      highlightStartIndex = -1
      highlightEndIndex = -1
