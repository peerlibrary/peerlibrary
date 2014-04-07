class Annotator.Plugin.DOMAnchors extends Annotator.Plugin
  # Plugin initialization
  pluginInit: ->
    @Annotator = Annotator
    @$ = Annotator.$

    # Register the creator for range selectors
    @annotator.selectorCreators.push
      name: 'DOMRangeSelector'
      describe: @getDOMRangeSelector

    # Register our anchoring strategy
    @annotator.anchoringStrategies.unshift
      name: 'domrange'
      code: @createFromDOMRangeSelector

    null

  # Create a DOMRangeSelector around a range
  getDOMRangeSelector: (selection) =>
    return [] unless selection.type is 'text range'
    sr = @serializeRange selection.range
    [
      type: 'DOMRangeSelector'
      startContainer: sr.startContainer
      startOffset: sr.startOffset
      endContainer: sr.endContainer
      endOffset: sr.endOffset
    ]

  domPathFromNode: (elem, relativeRoot) =>
    elem = elem.get(0)
    path = []
    while elem?.nodeType is Node.ELEMENT_NODE and elem isnt relativeRoot
      $elem = $(elem)
      $parent = $elem.parent()
      segment =
        # Tag name
        t: elem.tagName.toLowerCase()
        # Relative offset between same tag children
        r: $parent.children(elem.tagName).index(elem)
        # Absolute offset
        a: $parent.children().index(elem)
      # CSS classes
      segment.c = $elem.attr('class') if $elem.attr('class')
      # ID
      segment.i = $elem.attr('id') if $elem.attr('id')
      path.unshift segment
      elem = $parent.get(0)
    path

  serializeNode: (root, node, isEnd) =>
    origParent = $(node).parent()

    path = @domPathFromNode origParent, root
    textNodes = Annotator.Util.getTextNodes origParent

    # Calculate real offset as the combined length of all the
    # preceding textNode siblings. We include the length of the
    # node if it's the end node.
    nodes = textNodes.slice 0, textNodes.index(node)
    offset = 0
    for n in nodes
      offset += n.nodeValue.length

    if isEnd then [path, offset + node.nodeValue.length] else [path, offset]

  serializeRange: (range) =>
    root = @annotator.wrapper[0]

    start = @serializeNode root, range.start
    end = @serializeNode root, range.end, true

    startContainer: start[0]
    endContainer: end[0]
    startOffset: start[1]
    endOffset: end[1]

  # Look up the quote from the appropriate selector
  getQuoteForTarget: (target) =>
    selector = @annotator.findSelector target.selector, 'TextQuoteSelector'
    if selector?
      @annotator.normalizeString selector.exact
    else
      null

  _convertToXPath: (path) =>
    ("/#{ segment.t }[#{ segment.r + 1 }]" for segment in path).join ''

  deserializeRange: (selector) =>
    # TODO: Do smarter matching, but for now simply convert to XPath
    selector = _.clone selector
    selector.startContainer = @_convertToXPath selector.startContainer
    selector.endContainer = @_convertToXPath selector.endContainer
    new @Annotator.Range.SerializedRange selector

  # Create and anchor using the saved DOMRange selector.
  # The quote is verified. DTM is required.
  createFromDOMRangeSelector: (annotation, target) =>
    selector = @annotator.findSelector target.selector, 'DOMRangeSelector'
    return null unless selector?

    # Try to apply the saved path
    try
      range = @deserializeRange selector
      normedRange = range.normalize @annotator.wrapper[0]
    catch error
      return null

    # Get the text of this range
    startInfo = @annotator.domMapper.getInfoForNode normedRange.start
    startOffset = startInfo.start
    endInfo = @annotator.domMapper.getInfoForNode normedRange.end
    endOffset = endInfo.end
    currentQuote = @annotator.normalizeString @annotator.domMapper.getCorpus()[startOffset..endOffset-1]

    # Look up the saved quote
    savedQuote = @getQuoteForTarget target
    if savedQuote? and currentQuote isnt savedQuote
      return null

    # Create a TextPositionAnchor from the start and end offsets
    # of this range (to be used with dom-text-mapper)
    new @annotator.TextPositionAnchor @annotator, annotation, target, startInfo.start, endInfo.end, (startInfo.pageIndex ? 0), (endInfo.pageIndex ? 0), currentQuote
