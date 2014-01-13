class PDFTextHighlight extends Annotator.Highlight
  # Is this element a text highlight physical anchor?
  @isInstance: (element) =>
    false

  constructor: (anchor, pageIndex, @normedRange) ->
    super anchor, pageIndex

    @_$textLayer = $(@normedRange.commonAncestor).closest('.text-layer')
    @_$highlightsLayer = @_$textLayer.prev('.highlights-layer')

    @_$highlight = null

    @_createHighlight()

  _boundingBox: (segments) =>
    box = _.clone segments[0]

    for segment in segments[1..]
      if segment.left < box.left
        box.width += box.left - segment.left
        box.left = segment.left
      if segment.top < box.top
        box.height += box.top - segment.top
        box.top = segment.top
      if segment.left + segment.width > box.left + box.width
        box.width = segment.left + segment.width - box.left
      if segment.top + segment.height > box.top + box.height
        box.height = segment.top + segment.height - box.top

    box

  _wrapIntoBox: (segments) =>
    box = @_boundingBox segments

    # Making segments relative to the bounding box
    for segment in segments
      segment.left -= box.left
      segment.top -= box.top

    box

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

    box = @_wrapIntoBox segments

    @_$highlight = $('<div/>').addClass('highlights-layer-highlight').css(box).append(
      $('<div/>').addClass('highlights-layer-segment').css(segment) for segment in segments
    )

    @_$highlight.on 'click.highlight', (e) =>
      @anchor.annotator.deselectAllHighlights()
      @select()

    @_$highlight.on 'mouseenter.highlight', (e) =>
      @_$highlight.addClass 'hovered'

    @_$highlight.on 'mouseleave.highlight', (e) =>
      @_$highlight.removeClass 'hovered'

    @_$highlightsLayer.append @_$highlight

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

  # Get the HTML elements making up the highlight
  _getDOMElements: =>
    @_$highlight

class Annotator.Plugin.TextHighlights extends Annotator.Plugin
  pluginInit: =>
    Annotator.TextHighlight = PDFTextHighlight
