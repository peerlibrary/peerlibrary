class CanvasTextHighlight extends Annotator.Highlight
  constructor: (anchor, pageIndex, @normedRange) ->
    super anchor, pageIndex

    @_$selectionLayer = $(@normedRange.commonAncestor).closest('.selection-layer')
    @_$highlightsLayer = @_$selectionLayer.prev('.highlights-layer')
    @_highlightsCanvas = @_$highlightsLayer.prev('.highlights-canvas').get(0)
    @_$highlightsControl = @_$selectionLayer.next('.highlights-control')

    @_offset = @_$highlightsLayer.offsetParent().offset()

    @_area = null
    @_box = null
    @_hover = null
    @_$highlight = null

    # We are displaying hovering effect also when mouse is not really over the highlighting, but we
    # have to know if mouse is over the highlight to know if we should remove or not the hovering effect
    # TODO: Rename hovering effect to something else (engaged? active?) and then hovering and other actions should just engage highlight as neccessary
    # TODO: Sync this naming terminology with annotations (there are same states there)
    @_mouseHovering = false

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

    # We restore hovers for other highlights
    highlight._drawHover() for highlight in @anchor.annotator.getHighlights() when @pageIndex is highlight.pageIndex and highlight._$highlight.hasClass 'hovered'

  _sortHighlights: =>
    @_$highlightsLayer.find('.highlights-layer-highlight').detach().sort(
      (a, b) =>
        # Heuristics, we put smaller highlights later in DOM tree which means they will have higher z-index
        # The motivation here is that we want higher the highlight which leaves more area to the user to select the other highlight by not covering it
        # TODO: Should we improve here? For example, compare size of (A-B) and size of (B-A), where A-B is A with (A intersection B) removed
        $(b).data('highlight')._area - $(a).data('highlight')._area
    ).appendTo(@_$highlightsLayer)

  _showControl: =>
    $control = @_$highlightsControl.find('.meta-menu')

    return if $control.is(':visible')

    $control.css(
      left: @_box.left + @_box.width + 1 # + 1 to not overlap border
      top: @_box.top - 2 # - 1 to align with fake border we style
    ).on(
      'mouseover.highlight mouseout.highlight': @_hoverHandler
      'mouseenter-highlight': @_mouseenterHandler
      'mouseleave-highlight': @_mouseleaveHandler
    )

    # Create a reactive fragment. We fetch a reactive document
    # based on _id (which is immutable) to rerender the fragment
    # as document changes.
    highlightsControl = Meteor.render =>
      highlight = Highlight.documents.findOne @annotation?._id
      Template.highlightsControl highlight if highlight

    $control.find('.meta-content').empty().append(highlightsControl)
    $control.show()

  _hideControl: =>
    $control = @_$highlightsControl.find('.meta-menu')

    return unless $control.is(':visible') and not $control.is('.displayed')

    $control.hide().off(
      'mouseover.highlight mouseout.highlight': @_hoverHandler
      'mouseenter-highlight': @_mouseenterHandler
      'mouseleave-highlight': @_mouseleaveHandler
    )
    @_$highlightsControl.find('.meta-menu .meta-content .delete').off '.highlight'

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
    @_mouseHovering = true

    @hover false
    return # Make sure CoffeeScript does not return anything

  _mouseleaveHandler: (e) =>
    @_mouseHovering = false

    if @_$highlight.hasClass 'selected'
      @_hideControl()
    else
      @unhover false

    return # Make sure CoffeeScript does not return anything

  _highlightControlBlur: (e) =>
    # This event triggers when highlight control (its input) is not focused anymore
    return if @_$highlightsControl.find('.meta-menu').is(':hover')
    @_hideControl()
    return # Make sure CoffeeScript does not return anything

  hover: (noControl) =>
    # We have to check if highlight already is marked as hovered because of mouse events forwarding
    # we use, which makes the event be send twice, once when mouse really hovers the highlight, and
    # another time when user moves from a highlight to a control - in fact mouseover handler above
    # gets text layer as related target (instead of underlying highlight) so it makes a second event.
    # This would be complicated to solve, so it is easier to simply have this check here.
    if @_$highlight.hasClass 'hovered'
      # We do not do anything, but we still show control if it was not shown already
      @_showControl() unless noControl
      return

    @_$highlight.addClass 'hovered'
    @_drawHover()
    # When mouseenter handler is called by _annotationMouseenterHandler we do not want to show control
    @_showControl() unless noControl

    # We do not want to create a possible cycle, so trigger only if not called by _annotationMouseenterHandler
    $('.annotations-list .annotation').trigger 'highlightMouseenter', [@annotation._id] unless noControl

  unhover: (noControl) =>
    # Probably not really necessary to check if highlight already marked as hovered but to match check above
    unless @_$highlight.hasClass 'hovered'
      # We do not do anything, but we still hide control if it was not hidden already
      @_hideControl() unless noControl
      return

    @_$highlight.removeClass 'hovered'
    @_hideHover()
    # When mouseleave handler is called by _annotationMouseleaveHandler we do not want to show control
    @_hideControl() unless noControl

    # We do not want to create a possible cycle, so trigger only if not called by _annotationMouseleaveHandler
    $('.annotations-list .annotation').trigger 'highlightMouseleave', [@annotation._id] unless noControl

  _annotationMouseenterHandler: (e, annotationId) =>
    @hover true if annotationId in _.pluck @annotation.referencingAnnotations, '_id'
    return # Make sure CoffeeScript does not return anything

  _annotationMouseleaveHandler: (e, annotationId) =>
    @unhover true if annotationId in _.pluck @annotation.referencingAnnotations, '_id'
    return # Make sure CoffeeScript does not return anything

  _createHighlight: =>
    scrollLeft = $(window).scrollLeft()
    scrollTop = $(window).scrollTop()

    # We cannot simply use Range.getClientRects because it returns different
    # things in different browsers: in Firefox it seems to return almost precise
    # but a bit offset values (maybe just more testing would be needed), but in
    # Chrome it returns both text node and div node rects, so too many rects.
    # To assure cross browser compatibility, we compute positions of text nodes
    # in a range manually.
    segments = for node in @normedRange.textNodes()
      $node = $(node)
      $wrap = $node.wrap('<span/>').parent()
      rect = $wrap.get(0).getBoundingClientRect()
      $node.unwrap()

      left: rect.left + scrollLeft - @_offset.left
      top: rect.top + scrollTop - @_offset.top
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
      'annotationMouseenter': @_annotationMouseenterHandler
      'annotationMouseleave': @_annotationMouseleaveHandler
      'highlightControlBlur': @_highlightControlBlur

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
    @_mouseleaveHandler null

    $(@_$highlight).remove()

  # Just a helper function to draw highlight selected and make it selected by the browser, use annotator._selectHighlight to select
  select: =>
    selection = rangy.getSelection()
    selection.addRange @normedRange.toRange()

    @_$selectionLayer.addClass 'highlight-selected'
    @_$highlight.addClass 'selected'

    # We also want that selected annotations display a hover effect
    @hover true

  # Just a helper function to draw highlight unselected and make it unselected by the browser, use annotator._selectHighlight to deselect
  deselect: =>
    # Mark this highlight as deselected
    @_$highlight.removeClass 'selected'

    # First store any selection which is outside pages
    otherRanges = []
    selection = rangy.getSelection()
    for r in [0...selection.rangeCount]
      range = selection.getRangeAt r
      otherRanges.push range unless $(range.commonAncestorContainer).closest('.display-page').length

    # Deselect everything
    selection.removeAllRanges()

    # We will re-add it in highlight.select() if necessary
    $('.text-layer', @anchor.annotator.wrapper).removeClass 'highlight-selected'

    # And re-select highlights marked as selected
    highlight.select() for highlight in @anchor.annotator.getHighlights() when highlight.isSelected()

    # Reselect selections outside pages
    selection.addRange range for range in otherRanges

    # If mouse is not over the highlight we unhover
    @unhover true unless @_mouseHovering

  # Is highlight currently drawn as selected, use annotator.selectedAnnotationId to get ID of a selected annotation
  isSelected: =>
    @_$highlight.hasClass 'selected'

  in: (clientX, clientY) =>
    @_$highlight.find('.highlights-layer-segment').is (i) ->
      # @ (this) is here a segment, DOM element
      rect = @getBoundingClientRect()

      rect.left <= clientX <= rect.right and rect.top <= clientY <= rect.bottom

  # Get the HTML elements making up the highlight
  _getDOMElements: =>
    @_$highlight

  # Get bounding box with coordinates relative to the outer bounds of the display wrapper
  getBoundingBox: =>
    wrapperOffset = @anchor.annotator.wrapper.outerOffset()

    left: @_box.left + @_offset.left - wrapperOffset.left
    top: @_box.top + @_offset.top - wrapperOffset.top
    width: @_box.width
    height: @_box.height

class Annotator.Plugin.CanvasTextHighlights extends Annotator.Plugin
  pluginInit: =>
    # Register this highlighting implementation
    @annotator.highlighters.unshift
      name: 'Canvas text highlighter'
      highlight: @_createTextHighlight
      isInstance: @_isInstance
      getIndependentParent: @_getIndependentParent

  _createTextHighlight: (anchor, pageIndex) =>
    switch anchor.type
      when 'text range'
        new CanvasTextHighlight anchor, pageIndex, anchor.range
      when 'text position'
        # TODO: We could try to still create a range from trying to anchor with a DOM anchor again, and if it fails, go back to DTM

        # Cannot do this without DTM
        return unless @annotator.domMapper

        # First we create the range from the stored stard and end offsets
        mappings = @annotator.domMapper.getMappingsForCharRange anchor.start, anchor.end, [pageIndex]

        # Get the wanted range out of the response of DTM
        realRange = mappings.sections[pageIndex].realRange

        # Get a BrowserRange
        browserRange = new Annotator.Range.BrowserRange realRange

        # Get a NormalizedRange
        normedRange = browserRange.normalize @annotator.wrapper[0]

        # Create the highligh
        new CanvasTextHighlight anchor, pageIndex, normedRange
      else
        # Unsupported anchor type
        null

  # Is this element a text highlight physical anchor?
  _isInstance: (element) =>
    # Is always false because canvas highlights are completely independent from the content
    false

  # Find the first parent outside this physical anchor
  _getIndependentParent: (element) =>
    # Should never happen because canvas highlights are completely independent from the content
    assert false
