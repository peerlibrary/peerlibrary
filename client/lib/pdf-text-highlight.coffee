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

      $('<div/>').addClass('highlights-layer-segment').css
        left: rect.left + scrollLeft - offset.left
        top: rect.top + scrollTop - offset.top
        width: rect.width
        height: rect.height

    @_$highlight = $('<div/>').addClass('highlights-layer-highlight').append(segments)

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
