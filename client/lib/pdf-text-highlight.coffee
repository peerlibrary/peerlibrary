class PDFTextHighlight extends Annotator.Highlight
  # Is this element a text highlight physical anchor?
  @isInstance: (element) =>
    false

  constructor: (anchor, pageIndex, @normedRange) ->
    super anchor, pageIndex

    @_$textLayer = $(@normedRange.commonAncestor).closest('.text-layer')
    @_$highlightsLayer = @_$textLayer.prev('.highlights-layer')
    @_highlightsCanvas = @_$highlightsLayer.prev('.highlights-canvas').get(0)

    @_area = null
    @_hover = null
    @_$highlight = null

    @_createHighlight()

  _computeArea: (segments) =>
    @_area = 0

    for segment in segments
      @_area += segment.width * segment.height

    return # Don't return the result of the for loop

  _precomputeHover: (segments) =>
    # For now compute simply a bounding box
    # TODO: Compute a better polygon around all segments

    @_hover = _.clone segments[0]

    for segment in segments[1..]
      if segment.left < @_hover.left
        @_hover.width += @_hover.left - segment.left
        @_hover.left = segment.left
      if segment.top < @_hover.top
        @_hover.height += @_hover.top - segment.top
        @_hover.top = segment.top
      if segment.left + segment.width > @_hover.left + @_hover.width
        @_hover.width = segment.left + segment.width - @_hover.left
      if segment.top + segment.height > @_hover.top + @_hover.height
        @_hover.height = segment.top + segment.height - @_hover.top

    # Round to have integer coordinates on canvas
    @_hover.width += @_hover.left - Math.round(@_hover.left)
    @_hover.left = Math.round(@_hover.left)
    @_hover.width = Math.round(@_hover.width)
    @_hover.height += @_hover.top - Math.round(@_hover.top)
    @_hover.top = Math.round(@_hover.top)
    @_hover.height = Math.round(@_hover.height)

    return # Don't return the result of the for loop

  _drawHover: =>
    context = @_highlightsCanvas.getContext('2d')

    # Style used in variables.styl as well, keep it in sync
    # TODO: Ignoring rounded 2px border radius, implement

    context.save()

    context.lineWidth = 1
    # TODO: Colors do not really look the same if they are same as style in variables.styl, why?
    context.strokeStyle = 'rgba(14,41,57,0.32)'
    context.shadowColor = 'rgba(14,41,57,1.0)'
    context.shadowBlur = 5
    context.shadowOffsetX = 0
    context.shadowOffsetY = 2

    context.beginPath()
    context.rect @_hover.left - 1, @_hover.top - 1, @_hover.width + 2, @_hover.height + 2
    context.closePath()

    context.stroke()

    # As shadow is drawn both on inside and outside, we clear inside to give a nice 3D effect
    context.clearRect @_hover.left, @_hover.top, @_hover.width, @_hover.height

    context.restore()

  _hideHover: =>
    context = @_highlightsCanvas.getContext('2d')
    context.clearRect 0, 0, @_highlightsCanvas.width, @_highlightsCanvas.height

  _sortHighlights: =>
    @_$highlightsLayer.find('.highlights-layer-highlight').detach().sort(
      (a, b) =>
        # Heuristics, we put smaller highlights later in DOM tree which means they will have higher z-index
        # The motivation here is that we want higher the highlight which leaves more area to the user to select the other highlight by not covering it
        # TODO: Should we improve here? For example, compare size of (A-B) and size of (B-A), where A-B is A with (A intersection B) removed
        $(b).data('highlight')._area - $(a).data('highlight')._area
    ).appendTo(@_$highlightsLayer)

  _createHighlight: =>
    scrollLeft = $(window).scrollLeft()
    scrollTop = $(window).scrollTop()

    offset = @_$highlightsLayer.offsetParent().offset()

    # We cannot simply use Range.getClientRects because it returns different
    # things in different browsers: in Firefox it seems to return almost precise
    # but a bit offset values (maybe just more testing would be needed), but in
    # Chrome it returns both text node and div node rects, so too many rects.
    # To assure cross browser compatibilty, we compute positions of text nodes
    # in a range manually.
    segments = for node in @normedRange.textNodes()
      $node = $(node)
      $wrap = $node.wrap('<span/>').parent()
      rect = $wrap.get(0).getBoundingClientRect()
      $node.unwrap()

      left: rect.left + scrollLeft - offset.left
      top: rect.top + scrollTop - offset.top
      width: rect.width
      height: rect.height

    @_computeArea segments
    @_precomputeHover segments

    @_$highlight = $('<div/>').addClass('highlights-layer-highlight').append(
      $('<div/>').addClass('highlights-layer-segment').css(segment) for segment in segments
    )

    @_$highlight.find('.highlights-layer-segment').on
      'click.highlight': (e) =>
        @anchor.annotator.deselectAllHighlights()
        @select()

      'mouseenter.highlight': (e) =>
        @_$highlight.addClass 'hovered'
        @_drawHover()

      'mouseleave.highlight': (e) =>
        @_$highlight.removeClass 'hovered'
        @_hideHover()

    @_$highlight.data 'highlight', @

    @_$highlightsLayer.append @_$highlight

    @_sortHighlights()

  # React to changes in the underlying annotation
  annotationUpdated: =>
    # TODO: What to do when it is updated? What information do we get when it is updated?
    #console.log "In HL", @, "annotation has been updated.", arguments

  # Remove all traces of this highlight from the document
  removeFromDocument: =>
    $(@_$highlight).remove()

  select: =>
    selection = window.getSelection()
    selection.addRange @normedRange.toRange()

    @_$textLayer.addClass 'highlight-selected'
    @_$highlight.addClass 'selected'

  deselect: =>
    # Mark this highlight as deselected
    @_$highlight.removeClass 'selected'

    # Deselect everything
    selection = window.getSelection()
    selection.removeAllRanges()

    # We will re-add it in highlight.select() if necessary
    $('.text-layer').removeClass 'highlight-selected'

    # And re-select highlights marked as selected
    for highlight in @anchor.annotator.getHighlights()
      highlight.select() if highlight.isSelected()

  isSelected: =>
    @_$highlight.hasClass 'selected'

  in: (clientX, clientY) =>
    @_$highlight.find('.highlights-layer-segment').is (i) ->
      # @ (this) is here a segment, DOM element
      rect = @.getBoundingClientRect()

      rect.left <= clientX <= rect.right and rect.top <= clientY <= rect.bottom

  # Get the HTML elements making up the highlight
  _getDOMElements: =>
    @_$highlight

class Annotator.Plugin.TextHighlights extends Annotator.Plugin
  pluginInit: =>
    Annotator.TextHighlight = PDFTextHighlight
