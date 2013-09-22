LINE_HEIGHT_THRESHOLD = 0.5
LARGEST_LINE_HEIGHT_WINDOW = 0.07
SPLIT_SECTION_THRESHOLD = 1.1
SECTION_INDENT_THRESHOLD = 1.0 / 40.0
SPLIT_PARAGRAPH_THRESHOLD = 0.9

# Merges sorted lists in sorted list with unique elements
merge = (list1, list2) ->
  i = 0
  j = 0
  list = []

  while i < list1.length and j < list2.length
    if list1[i] < list2[j]
      list.push list1[i] unless list[list.length - 1] == list1[i]
      i++
    else if list2[j] < list1[i]
      list.push list2[j] unless list[list.length - 1] == list2[j]
      j++
    else if list1[i] == list2[j]
      list.push list1[i] unless list[list.length - 1] == list1[i]
      i++
      j++
    else
      assert false

  while i < list1.length
    list.push list1[i] unless list[list.length - 1] == list1[i]
    i++

  while j < list2.length
    list.push list2[j] unless list[list.length - 1] == list2[j]
    j++

  list

# TODO: We should really move pages into their own objects so that we do not have to pass pageNumber everywhere around

class @Annotator
  constructor: ->
    @_pages = []
    @_activeHighlightStart = null
    @_activeHighlightEnd = null

  setPage: (page) =>
    # Initialize the page
    @_pages[page.pageNumber - 1] =
      page: page
      pageNumber: page.pageNumber
      textSegments: []
      imageSegments: []
      highlightsEnabled: false
      lineHeight: null
      paragraphs: []

  setTextContent: (pageNumber, textContent) =>
    @_pages[pageNumber - 1].textContent = textContent

  _dy: (pageNumber, i) =>
    page = @_pages[pageNumber - 1]
    page.textSegments[i + 1].top - page.textSegments[i].top

  _computeLineHeight: (pageNumber) =>
    page = @_pages[pageNumber - 1]

    dys = []
    for segment, i in page.textSegments
      continue if i is page.textSegments.length - 1 # Skip the last one

      dy = @_dy pageNumber, i
      if dy > 0
        dys.push
          dy: dy
          area: segment.width * segment.height

    return unless dys.length

    dys = dys.sort (a, b) -> a.dy - b.dy
    lineHeights = []
    for dy in dys
      lastLineHeights = lineHeights[lineHeights.length - 1]
      if lastLineHeights and Math.abs(lastLineHeights.average - dy.dy) < LINE_HEIGHT_THRESHOLD * SCALE
        lastLineHeights.average = ((lastLineHeights.average * lastLineHeights.count) + dy.dy) / (lastLineHeights.count + 1)
        lastLineHeights.area += dy.area
        lastLineHeights.count++
      else
        lineHeights.push
          average: dy.dy
          count: 1
          area: dy.area

    combinedArea = 0
    for lineHeight in lineHeights
      combinedArea += lineHeight.area

    lineHeights.sort (a, b) -> b.area - a.area

    # We prefer not splitting real paragraphs, so we are selecting the largest
    # line height among a window of line heights based on their area
    largestLineHeight = 0
    for lineHeight in lineHeights
      if lineHeight.area / combinedArea < lineHeights[0].area / combinedArea - LARGEST_LINE_HEIGHT_WINDOW * SCALE
        break

      if lineHeight.average > largestLineHeight
        largestLineHeight = lineHeight.average

    page.lineHeight = largestLineHeight

  _boundingBox: (pageNumber, segmentsIndices) =>
    page = @_pages[pageNumber - 1]

    top = Number.MAX_VALUE
    bottom = 0
    left = Number.MAX_VALUE
    right = 0

    for i in segmentsIndices
      segment = page.textSegments[i]

      left = Math.min left, segment.left
      right = Math.max right, (segment.left + segment.width)
      top = Math.min top, segment.top
      bottom = Math.max bottom, (segment.top + segment.height)

    left: left
    top: top
    width: right - left
    height: bottom - top

  _areasOverlap: (area1, area2) =>
    area1right = area1.left + area1.width
    area2right = area2.left + area2.width
    area1bottom = area1.top + area1.height
    area2bottom = area2.top + area2.height

    area1.left < area2right and area1right > area2.left and area1.top < area2bottom and area1bottom > area2.top

  # TODO: We could cache bounding boxes and not recompute every time for the same section (of course we have to udpate it when we merge sections)
  _mergeOverlappingSections: (pageNumber, sections) =>
    changed = true
    while changed
      changed = false

      i = 0
      while i < sections.length - 1
        j = i + 1
        while j < sections.length
          area1 = @_boundingBox pageNumber, sections[i]
          area2 = @_boundingBox pageNumber, sections[j]

          if @_areasOverlap area1, area2
            # We merge into the first section
            sections[i] = merge sections[i], sections[j]

            # We remove the second section
            sections.splice j, 1

            changed = true

          j++

        i++

    sections

  # Sections must be areas of PDF where we do NOT split any real paragraph by mistake
  # They can contain one or more paragaphs and other elements
  # They must not overlap as well (those should be merged together)
  _splitSections: (pageNumber) =>
    page = @_pages[pageNumber - 1]

    s = 0
    sections = []
    for segment, i in page.textSegments
      continue if i is page.textSegments.length - 1 # Skip the last one, @_dy checks this and the next one

      if Math.abs(@_dy pageNumber, i) > page.lineHeight * SPLIT_SECTION_THRESHOLD * SCALE
        sections.push [s..i] # Inclusive range (..) here
        s = i + 1

    sections.push [s...page.textSegments.length] # Exclusive range (...) here

    @_mergeOverlappingSections pageNumber, sections

  _sectionIndentThreshold: (pageNumber, segmentsIndices) =>
    page = @_pages[pageNumber - 1]

    left = Number.MAX_VALUE
    right = 0

    for i in segmentsIndices
      segment = page.textSegments[i]

      left = Math.min left, segment.left
      right = Math.max right, (segment.left + segment.width)

    left + (right - left) * SECTION_INDENT_THRESHOLD * SCALE

  _splitParagraphs: (pageNumber, segments, sectionIndentThreshold) =>
    page = @_pages[pageNumber - 1]

    s = start
    paragraphs = []
    for segment, i in page.textSegments[start...end - 1]
      if Math.abs(@_dy pageNumber, i) < page.lineHeight * SPLIT_PARAGRAPH_THRESHOLD * SCALE and segment.left > sectionIndentThreshold
        paragraphs.push [s, i + 1]
        s = i + 1

    paragraphs.push [s, end]
    paragraphs

  _processParagraph: (pageNumber, segmentsIndices) =>
    page = @_pages[pageNumber - 1]

    page.paragraphs.push @_boundingBox pageNumber, segmentsIndices

  _processSection: (pageNumber, segmentsIndices) =>
    sectionIndentThreshold = @_sectionIndentThreshold pageNumber, segmentsIndices

    for segsIs in @_splitParagraphs pageNumber, segmentsIndices, sectionIndentThreshold
      @_processParagraph pageNumber, segsIs

  _roundArea: (area) =>
    areaRounded = _.clone area
    areaRounded.left = Math.floor areaRounded.left
    areaRounded.top = Math.floor areaRounded.top
    areaRounded.width += area.left - areaRounded.left
    areaRounded.height += area.top - areaRounded.top
    areaRounded.width = Math.ceil areaRounded.width
    areaRounded.height = Math.ceil areaRounded.height
    areaRounded

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
      page.imageSegments.push _.pick(geom, 'left', 'top', 'width', 'height')

  # For debugging: draw divs for all segments
  _showSegments: (pageNumber) =>
    page = @_pages[pageNumber - 1]
    $displayPage = $("#display-page-#{ pageNumber }")

    for segment in page.textSegments
      $displayPage.append(
        $('<div/>').addClass('segment text-segment').css _.pick(segment, 'left', 'top', 'width', 'height')
      )

    for segment in page.imageSegments
      $displayPage.append(
        $('<div/>').addClass('segment image-segment').css  _.pick(segment, 'left', 'top', 'width', 'height')
      )

  # For debugging: draw divs for all paragraphs
  _showParagraphs: (pageNumber) =>
    page = @_pages[pageNumber - 1]
    $displayPage = $("#display-page-#{ pageNumber }")

    for paragraph in page.paragraphs
      $displayPage.append(
        $('<div/>').addClass('paragraph').css _.pick(paragraph, 'left', 'top', 'width', 'height')
      )

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

  _findClosestPage: (position) =>
    $closestCanvas = null
    closestPageNumber = -1
    closestDistance = Number.MAX_VALUE

    $('.display-page canvas').each (i, canvas) =>
      $canvas = $(canvas)
      pageNumber = $canvas.data 'page-number'

      return unless @_pages[pageNumber - 1]?.highlightsEnabled

      offset = $canvas.offset()
      distance = @_distance position,
        left: offset.left
        top: offset.top
        width: $canvas.width()
        height: $canvas.height()
      if distance < closestDistance
        $closestCanvas = $canvas
        closestPageNumber = pageNumber
        closestDistance = distance

    assert.notEqual closestPageNumber, -1
    assert $closestCanvas

    [$closestCanvas, closestPageNumber]

  _findClosestSegment: (pageNumber, position) =>
    page = @_pages[pageNumber - 1]

    closestSegmentIndex = -1
    closestDistance = Number.MAX_VALUE

    for segment, i in page.textSegments
      distance = @_distance position, segment
      if distance < closestDistance
        closestSegmentIndex = i
        closestDistance = distance

    closestSegmentIndex

  _normalizeActiveHighlightStartEnd: =>
    if @_activeHighlightStart.pageNumber < @_activeHighlightEnd.pageNumber
      # We don't have to do anything
      return [@_activeHighlightStart, @_activeHighlightEnd]
    else if @_activeHighlightStart.pageNumber > @_activeHighlightEnd.pageNumber
      # We just swap
      return [@_activeHighlightEnd, @_activeHighlightStart]

    # Start and end are on the same page

    if @_activeHighlightStart.index < @_activeHighlightEnd.index
      # We don't have to do anything
      return [@_activeHighlightStart, @_activeHighlightEnd]
    else if @_activeHighlightStart.index > @_activeHighlightEnd.index
      # We just swap
      return [@_activeHighlightEnd, @_activeHighlightStart]

    # Start and end are in the same segment, we prefer the left point (and top)

    # TODO: What about right-to-left texts? Or top-down texts?
    if @_activeHighlightStart.left < @_activeHighlightEnd.left
      return [@_activeHighlightStart, @_activeHighlightEnd]
    else if @_activeHighlightStart.left > @_activeHighlightEnd.left
      return [@_activeHighlightEnd, @_activeHighlightStart]

    # Left coordinates are equal, we prefer top one

    if @_activeHighlightStart.top < @_activeHighlightEnd.top
      return [@_activeHighlightStart, @_activeHighlightEnd]
    else
      return [@_activeHighlightEnd, @_activeHighlightStart]

  _hideActiveHiglight: =>
    $(".display-page .highlight").remove()

  _showActiveHighlight: =>
    # TODO: It is costy to first hide (remove) everything and the reshow (add), we should reuse things if we can
    @_hideActiveHiglight()

    assert @_activeHighlightStart
    assert @_activeHighlightEnd

    [activeHighlightStart, activeHighlightEnd] = @_normalizeActiveHighlightStartEnd()

    if activeHighlightStart.pageNumber is activeHighlightEnd.pageNumber
      $displayPage = $("#display-page-#{ activeHighlightStart.pageNumber }")

      textSegments = @_pages[activeHighlightStart.pageNumber - 1].textSegments
      for segment in textSegments[activeHighlightStart.index..activeHighlightEnd.index]
        $displayPage.append(
          $('<div/>').addClass('highlight').css _.pick(segment, 'left', 'top', 'width', 'height')
        )
    else
      # Show for the first page

      $displayPage = $("#display-page-#{ activeHighlightStart.pageNumber }")

      textSegments = @_pages[activeHighlightStart.pageNumber - 1].textSegments
      for segment in textSegments[activeHighlightStart.index...textSegments.length] # Exclusive range (...) here instead of inclusive (..)
        $displayPage.append(
          $('<div/>').addClass('highlight').css _.pick(segment, 'left', 'top', 'width', 'height')
        )

      # Show intermediate pages

      for page in @_pages[activeHighlightStart.pageNumber...(activeHighlightEnd.pageNumber - 1)] # Range without the first and the last pages
        continue unless page?.highlightsEnabled

        $displayPage = $("#display-page-#{ page.pageNumber }")

        for segment in page.textSegments
          $displayPage.append(
            $('<div/>').addClass('highlight').css _.pick(segment, 'left', 'top', 'width', 'height')
          )

      # Show for the last page

      $displayPage = $("#display-page-#{ activeHighlightEnd.pageNumber }")

      textSegments = @_pages[activeHighlightEnd.pageNumber - 1].textSegments
      for segment in textSegments[0..activeHighlightEnd.index] # Inclusive range (..) here
        $displayPage.append(
          $('<div/>').addClass('highlight').css _.pick(segment, 'left', 'top', 'width', 'height')
        )

  _openActiveHighlight: =>
    # TODO: Implement

  _closeActiveHighlight: =>
    @_hideActiveHiglight()

    # TODO: Implement

  _enableHighligts: (pageNumber) =>
    page = @_pages[pageNumber - 1]

    return unless page.textSegmentsDone and page.imageLayerDone

    # Highlights already enabled for this page
    return if page.highlightsEnabled
    page.highlightsEnabled = true

    # For debugging
    #@_showSegments pageNumber

    @_computeLineHeight pageNumber

    for segmentsIndices in @_splitSections pageNumber
      @_processParagraph pageNumber, segmentsIndices

    # For debugging
    @_showParagraphs pageNumber

    $canvas = $("#display-page-#{ pageNumber } canvas")

    $canvas.on 'mousedown', (e) =>
      offset = $canvas.offset()
      left = e.pageX - offset.left
      top = e.pageY - offset.top
      index = @_findClosestSegment pageNumber,
        left: left
        top: top

      return if index is -1

      @_activeHighlightStart =
        pageNumber: pageNumber
        left: left
        top: top
        index: index

      $(document).on 'mousemove.highlighting', (e) =>
        assert @_activeHighlightStart

        [$c, pn] = @_findClosestPage
          left: e.pageX
          top: e.pageY
        offset = $c.offset()
        left = e.pageX - offset.left
        top = e.pageY - offset.top
        index = @_findClosestSegment pn,
          left: left
          top: top

        return if index is -1

        @_activeHighlightEnd =
          pageNumber: pn
          left: left
          top: top
          index: index

        @_showActiveHighlight()

      $(document).on 'mouseup.highlighting', (e) =>
        $(document).off '.highlighting'

        assert @_activeHighlightStart

        [$c, pn] = @_findClosestPage
          left: e.pageX
          top: e.pageY
        offset = $c.offset()
        left = e.pageX - offset.left
        top = e.pageY - offset.top
        index = @_findClosestSegment pn,
          left: left
          top: top

        if index is -1
          @_closeHighlight()
          return

        @_activeHighlightEnd =
          pageNumber: pn
          left: left
          top: top
          index: index

        if @_activeHighlightStart.left is @_activeHighlightEnd.left and @_activeHighlightStart.top is @_activeHighlightEnd.top
          # Mouse went up at the same location that it started, we just cleanup
          @_closeActiveHighlight()
        else
          @_openActiveHighlight()

        @_activeHighlightStart = null
        @_activeHighlightEnd = null
