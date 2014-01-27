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
    # TODO: Improve polygon drawing, split segment array by chunks 

    # _hover is an array of vertices coordinates
    @_hover = []
    @_hover.push([Math.round(segments[0].left), Math.round(segments[0].top + segments[0].height)])
    @_hover.push([Math.round(segments[0].left), Math.round(segments[0].top)])

    curr = segments[0]
    i = 1
    while i < segments.length
      # check to see if next segment is on a different line
      if (segments[i].top > curr.top) and ((segments[i].top + segments[i].height) > (curr.top + curr.height))
        @_hover.push([Math.round(segments[i-1].left + segments[i-1].width), Math.round(segments[i-1].top)])
        @_hover.push([Math.round(segments[i-1].left + segments[i-1].width), Math.round(segments[i-1].top + segments[i-1].height)])
        curr = segments[i]
      i++

    # compute bottom right vertices
    @_hover.push([Math.round(segments[segments.length-1].left + segments[segments.length-1].width), Math.round(segments[segments.length-1].top)])
    @_hover.push([Math.round(segments[segments.length-1].left + segments[segments.length-1].width), Math.round(segments[segments.length-1].top + segments[segments.length-1].height)])

    curr = segments[segments.length-1]
    i = segments.length-2
    while i > 0
      if (segments[i].top < curr.top) and ((segments[i].top + segments[i].height) < (curr.top + curr.height))
        @_hover.push([Math.round(segments[i+1].left),Math.round(segments[i+1].top + segments[i+1].height)])
        @_hover.push([Math.round(segments[i+1].left),Math.round(segments[i+1].top)])
        curr = segments[i]
      i--

    return  # Don't return the result of the for loop

  _drawHover: =>
    context = @_highlightsCanvas.getContext('2d')

    # Style used in variables.styl as well, keep it in sync
    # TODO: Ignoring rounded 2px border radius, implement

    context.save()

    context.lineWidth = 1
    # TODO: Colors do not really look the same if they are same as style in variables.styl, why?
    context.strokeStyle = 'rgba(180,170,0,9)'
    #context.shadowColor = 'rgba(14,41,57,1.0)'
    #context.shadowBlur = 5
    #context.shadowOffsetX = 0
    #context.shadowOffsetY = 2

    context.beginPath()
    #context.strokeRect @_hover.start_x, @_hover.start_y, @_hover.width + 2, @_hover.height+2
    #context.strokeRect @_hover.left - 1, @_hover.top - 1, @_hover.width + 2, @_hover.height + 2
    context.moveTo(@_hover[0][0], @_hover[0][1])
    for vertex in @_hover[1..]
      context.lineTo(vertex[0],vertex[1])
    context.closePath()

    context.stroke()

    # As shadow is drawn both on inside and outside, we clear inside to give a nice 3D effect
    # context.clearRect @_hover.left, @_hover.top, @_hover.width, @_hover.height

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
    $control = @_$highlightsControl.find('.control')
    $control.css(
      left: @_box.left + @_box.width + 1 # + 1 to not overlap border
      top: @_box.top - 2 # - 1 to align with fake border we style
    ).on(
      'mouseover.highlight mouseout.highlight': @_hoverHandler
      'mouseenter-highlight': @_mouseenterHandler
      'mouseleave-highlight': @_mouseleaveHandler
    )

    $control.find('.meta-content').html(Template.highlightsControl()).find('.delete').on 'click.highlight', (e) =>
      @anchor.annotator._removeHighlight @annotation._id

      return # Make sure CoffeeScript does not return anything

    $control.show()

  _hideControl: =>
    @_$highlightsControl.find('.control').hide().off(
      'mouseover.highlight mouseout.highlight': @_hoverHandler
      'mouseenter-highlight': @_mouseenterHandler
      'mouseleave-highlight': @_mouseleaveHandler
    )
    @_$highlightsControl.find('.control .meta-content .delete').off '.highlight'

  _clickHandler: (e) =>
    @anchor.annotator._selectHighlight @annotation._id

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

    # Annotator's anchors are realized (Annotator's highlight is created) when page is rendered
    # and virtualized (Annotator's highlight is destroyed) when page is removed. This mostly happens
    # as user scrolls around. But we want that if our highlight (Annotator's annotation) is selected
    # (selectedAnnotationId is set) when it is realized, it is drawn as selected and also that it is
    # really selected in the browser as a selection. So we do this here.
    @select() if @anchor.annotator.selectedAnnotationId is @annotation._id

  # React to changes in the underlying annotation
  annotationUpdated: =>
    # TODO: What to do when it is updated? Can we plug in reactivity somehow? To update template automatically?
    #console.log "In HL", @, "annotation has been updated."

  # Remove all traces of this highlight from the document
  removeFromDocument: =>
    # When removing, first we have to deselect it and just then remove it, otherwise
    # if this particular highlight is created again browser reselection does not
    # work (tested in Chrome). It seems if you have a selection and remove DOM
    # of text which is selected and then put DOM back and try to select it again,
    # nothing happens, no new browser selection is made. So what was happening
    # was that if you had a highlight selected on the first page (including
    # browser selection of the text in the highlight) and you scroll away so that
    # page was removed and then scroll back for page to be rendered again and
    # highlight realized (created) again, _createHighlight correctly called select
    # on the highlight, all CSS classes were correctly applied (making highlight
    # transparent), but browser selection was not made on text. If we deselect
    # when removing, then reselecting works correctly.
    @deselect() if @anchor.annotator.selectedAnnotationId is @annotation._id

    # We fake mouse leaving if highlight was hovered by any chance
    # (this happens when you remove a highlight through a control).
    @_mouseleaveHandler()

    $(@_$highlight).remove()

  # Just a helper function to draw highlight selected and make it selected by the browser, use annotator._selectHighlight to select
  select: =>
    selection = window.getSelection()
    selection.addRange @normedRange.toRange()

    @_$textLayer.addClass 'highlight-selected'
    @_$highlight.addClass 'selected'

  # Just a helper function to draw highlight unselected and make it unselected by the browser, use annotator._selectHighlight to deselect
  deselect: =>
    # Mark this highlight as deselected
    @_$highlight.removeClass 'selected'

    # Deselect everything
    selection = window.getSelection()
    selection.removeAllRanges()

    # We will re-add it in highlight.select() if necessary
    $('.text-layer', @anchor.annotator.wrapper).removeClass 'highlight-selected'

    # And re-select highlights marked as selected
    highlight.select() for highlight in @anchor.annotator.getHighlights() when highlight.isSelected()

  # Is highlight currently drawn as selected, use annotator.selectedAnnotationId to get ID of a selected annotation
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
