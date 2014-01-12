class PDFTextHighlight extends Annotator.Highlight
  # Is this element a text highlight physical anchor?
  @isInstance: (element) =>
    false

  constructor: (anchor, pageIndex, normedRange) ->
    super anchor, pageIndex

    @_$highlight = $()
    @_createHighlight normedRange

  _createHighlight: (normedRange) =>
    scrollLeft = $(window).scrollLeft()
    scrollTop = $(window).scrollTop()

    $layer = $(normedRange.commonAncestor).closest('.text-layer').prev('.highlights-layer')
    offset = $layer.offsetParent().offset()

    # In measuring text nodes positions below we confuse current selection,
    # so we wave it here to be able to restore it
    # Current selection is not necessary the same as normedRange, which is
    # the range of current highlight
    selection = window.getSelection()
    # We have to use Annotator's normalized ranges because otherwise saved
    # ranges does not seems to work correctly accross browsers and are simply
    # incomplete when restored
    # Normalization does not really cost much because we will normalize this
    # selection anyway at some point
    # TODO: Do all this only if selection has the same commonAncestor as normedRange? savedRanges should then be simply empty
    savedRanges = (new Annotator.Range.BrowserRange(selection.getRangeAt(i)).normalize() for i in [0...selection.rangeCount])

    # We cannot simply use Range.getClientRects because it returns different
    # things in different browsers: in Firefox it seems to return almost precise
    # but a bit offset values (maybe just more testing would be needed), but in
    # Chrome it returns both text node and div node rects, so too many rects.
    # To assure cross browser compatibilty, we compute positions of text nodes
    # in a range manually.
    segments = for node in normedRange.textNodes()
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

    # Restore selection
    if savedRanges.length
      selection = window.getSelection();
      selection.removeAllRanges()
      for range in savedRanges
        selection.addRange range.toRange()

    $layer.append @_$highlight

  # React to changes in the underlying annotation
  annotationUpdated: =>
    # TODO: What to do when it is updated? What information do we get when it is updated?
    #console.log "In HL", @, "annotation has been updated.", arguments

  # Remove all traces of this highlight from the document
  removeFromDocument: =>
    $(@_$highlight).remove()

  # Get the HTML elements making up the highlight
  _getDOMElements: =>
    @_$highlight

class Annotator.Plugin.TextHighlights extends Annotator.Plugin
  pluginInit: =>
    Annotator.TextHighlight = PDFTextHighlight
