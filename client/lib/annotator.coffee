WHITESPACE_REGEX = /\s+/g

class @Annotator.Plugin.TextAnchors extends Annotator.Plugin.TextAnchors
  checkForEndSelection: (event) =>
    if event
      event.previousMousePosition = @annotator.mousePosition
      @annotator.mousePosition = null

    super event

class @Annotator extends Annotator
  mousePosition: null

  constructor: (@_highlighter) ->
    super $('.display-wrapper'),
      noScan: true
    delete @options.noScan

  _setupViewer: =>
    # Overridden and disabled

    @ # For chaining

  _setupEditor: =>
    # Overridden and disabled

    @ # For chaining

  _setupDynamicStyle: =>
    # Overridden and disabled

    @ # For chaining

  startViewerHideTimer: =>
    # Overridden and disabled

  clearViewerHideTimer: =>
    # Overridden and disabled

  _setupWrapper: =>
    @wrapper = $(@element)

    @ # For chaining

  _setupDocumentEvents: =>
    $(document).on 'mousedown': (e) =>
      @checkForStartSelection e if e.which is 1 # Left mouse button
      return # Make sure CoffeeScript does not return anything

    @ # For chaining

  deselectAllHighlights: =>
    for highlight in @getHighlights()
      highlight.deselect()

  checkForStartSelection: (event) =>
    super

    # Not sure when event will not be defined, but parent
    # implementation takes that into the consideration
    if event
      @mousePosition =
        pageX: event.pageX
        pageY: event.pageY

    # We are starting a new selection, so deselect any selected highlight
    @deselectAllHighlights()

  confirmSelection: (event) =>
    return true unless @selectedTargets.length is 1

    # event.previousMousePosition might not exist if checkForEndSelection was called manually without an event object
    return false if event.previousMousePosition and Math.abs(event.previousMousePosition.pageX - event.pageX) <= 1 and Math.abs(event.previousMousePosition.pageY - event.pageY) <= 1

    quote = @plugins.TextAnchors.getQuoteForTarget @selectedTargets[0]
    # Quote should be non-empty string
    return false unless quote

    # Quote should not be empty when we remove all whitespace
    return false unless quote.replace(WHITESPACE_REGEX, '')

    true

  onSuccessfulSelection: (event, immediate) =>
    assert event
    assert event.targets

    # Store the selected targets
    @selectedTargets = event.targets

    return unless @confirmSelection event

    time = new Date().valueOf()

    annotation = @createAnnotation()

    # Extract the quotation and serialize the ranges
    annotation = @setupAnnotation annotation

    # Remove existing selection (the one we just made)
    @deselectAllHighlights()

    # And re-select it as a selected highlight
    for highlight in @getHighlights [annotation]
      highlight.select()

    console.log "Time (s):", (new Date().valueOf() - time) / 1000

    # TODO: Do something with annotation
    console.log annotation

    return # Make sure CoffeeScript does not return anything

  onFailedSelection: (event) =>
    super

    return # Make sure CoffeeScript does not return anything
