class PDFTextHighlight extends Annotator.Highlight
  # Is this element a text highlight physical anchor?
  @isInstance: (element) =>
    false

  constructor: (anchor, pageIndex, @normedRange) ->
    super anchor, pageIndex

    @_$textLayer = $(@normedRange.commonAncestor).closest('.text-layer')
    @_$highlightsLayer = @_$textLayer.prev('.highlights-layer')
    @_highlightsCanvas = @_$highlightsLayer.prev('.highlights-canvas').get(0)
    @_$highlightsControl = @_$textLayer.next('.highlights-control')

    @_area = null
    @_box = null
    @_hover = null
    @_$highlight = null

    @_createHighlight()

  _computeArea: (segments) =>
    @_area = 0

    for segment in segments
      @_area += segment.width * segment.height

    return # Don't return the result of the for loop

  _boundingBox: (segments) =>
    @_box = _.clone segments[0]

    for segment in segments[1..]
      if segment.left < @_box.left
        @_box.width += @_box.left - segment.left
        @_box.left = segment.left
      if segment.top < @_box.top
        @_box.height += @_box.top - segment.top
        @_box.top = segment.top
      if segment.left + segment.width > @_box.left + @_box.width
        @_box.width = segment.left + segment.width - @_box.left
      if segment.top + segment.height > @_box.top + @_box.height
        @_box.height = segment.top + segment.height - @_box.top

  _precomputeHover: (segments) =>
    # For now reuse simply a bounding box
    # TODO: Compute a better polygon around all segments

    @_hover = _.clone @_box

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

  _showControl: =>
    @_$highlightsControl.find('.control').css(
      left: @_box.left + @_box.width + 1 # + 1 to not overlap border
      top: @_box.top - 2 # - 1 to align with fake border we style
    ).on(
      'mouseover.highlight mouseout.highlight': @_hoverHandler
      'mouseenter-highlight': @_mouseenterHandler
      'mouseleave-highlight': @_mouseleaveHandler
    ).show()

  _hideControl: =>
    @_$highlightsControl.find('.control').hide().off(
      'mouseover.highlight mouseout.highlight': @_hoverHandler
      'mouseenter-highlight': @_mouseenterHandler
      'mouseleave-highlight': @_mouseleaveHandler
    )

  _clickHandler: (e) =>
    @anchor.annotator.deselectAllHighlights()
    @select()

    return # Make sure CoffeeScript does not return anything

  # We process mouseover and mouseout manually to trigger custom mouseenter and mouseleave events.
  # The difference is that we do $.contains($highlightAndControl, related) instead of $.contains(target, related).
  # We check if related is a child of highlight or control, and not checking only for one of those.
  # This is necessary so that mouseleave event is not made when user moves mouse from a highlight
  # to a control. jQuery's mouseleave is made because target is not the same as $highlightAndControl.
  _hoverHandler: (e) =>
    $highlightAndControl = @_$highlight.add(@_$highlightsControl)

    target = e.target
    related = e.relatedTarget

    # No relatedTarget if the mouse left/entered the browser window
    if not related or (not $highlightAndControl.is(related) and not $highlightAndControl.has(related).length)
      if e.type is 'mouseover'
        e.type = 'mouseenter-highlight'
        $(target).trigger e
        e.type = 'mouseover'
      else if e.type is 'mouseout'
        e.type = 'mouseleave-highlight'
        $(target).trigger e
        e.type = 'mouseout'

  _mouseenterHandler: (e) =>
    # We have to check if highlight already is marked as hovered because of mouse events forwarding
    # we use, which makes the event be send twice, once when mouse really hovers the highlight, and
    # another time when user moves from a highlight to a control - in fact mouseover handler above
    # gets text layer as related target (instead of underlying highlight) so it makes a second event.
    # This would be complicated to solve, so it is easier to simply have this check here.
    return if @_$highlight.hasClass 'hovered'

    @_$highlight.addClass 'hovered'
    @_drawHover()
    @_showControl()

    return # Make sure CoffeeScript does not return anything

  _mouseleaveHandler: (e) =>
    # Probably not really necessary to check if highlight already marked as hovered but to match check above
    return unless @_$highlight.hasClass 'hovered'

    @_$highlight.removeClass 'hovered'
    @_hideHover()
    @_hideControl()

    return # Make sure CoffeeScript does not return anything

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
    @_boundingBox segments
    @_precomputeHover segments

    @_$highlight = $('<div/>').addClass('highlights-layer-highlight').append(
      $('<div/>').addClass('highlights-layer-segment').css(segment) for segment in segments
    ).on
      'click.highlight': @_clickHandler
      'mouseover.highlight mouseout.highlight': @_hoverHandler
      'mouseenter-highlight': @_mouseenterHandler
      'mouseleave-highlight': @_mouseleaveHandler

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
