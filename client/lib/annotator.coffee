WHITESPACE_REGEX = /\s+/g

class @Annotator.Plugin.TextAnchors extends Annotator.Plugin.TextAnchors
  checkForEndSelection: (event) =>
    # Just to be sure we reset the variable
    @mouseStartingInsideSelectedHighlight = false

    if event
      return unless @annotator.mouseIsDown

      return unless event.which is 1 # Left mouse button

      event.previousMousePosition = @annotator.mousePosition
      @annotator.mousePosition = null

      # If click (mousedown coordinates same as mouseup coordinates) is on existing selected highlight,
      # we prevent default to prevent deselection of the highlight
      if event.previousMousePosition and event.previousMousePosition.pageX - event.pageX == 0 and event.previousMousePosition.pageY - event.pageY == 0 and @annotator._inAnySelectedHighlight event.clientX, event.clientY
        event.preventDefault()

    super event

    return # Make sure CoffeeScript does not return anything

class @Annotator extends Annotator
  mouseStartingInsideSelectedHighlight: false
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

  _inAnySelectedHighlight: (clientX, clientY) =>
    for highlight in @getHighlights() when highlight.isSelected()
      return true if highlight.in clientX, clientY

    false

  _setupDocumentEvents: =>
    $(document).on 'mousedown': (e) =>
      inAnySelectedHighlight = @_inAnySelectedHighlight e.clientX, e.clientY

      # If mousedown happened outside any selected highlight, we deselect highlights
      @deselectAllHighlights() unless inAnySelectedHighlight

      # Left mouse button and mousedown happened on a target inside a display-page
      # (We have mousedown evente handler on document to be able to always deselect,
      # but then we have to manually determine if event target is inside a display-page)
      if e.which is 1 and $(e.target).parents().is('.display-page')
        # To be able to correctly deselect in mousemove handler
        @mouseStartingInsideSelectedHighlight = inAnySelectedHighlight

        @checkForStartSelection e

      return # Make sure CoffeeScript does not return anything

    $(document).on 'mousemove': (e) =>
      # We started moving for a new selection, so deselect any selected highlight
      if @mouseIsDown and @mouseStartingInsideSelectedHighlight
        # To deselect only at the first mousemove event, otherwise any (new) selection would be impossible
        @mouseStartingInsideSelectedHighlight = false

        @deselectAllHighlights()

      return # Make sure CoffeeScript does not return anything

    @ # For chaining

  deselectAllHighlights: =>
    highlight.deselect() for highlight in @getHighlights()

  checkForStartSelection: (event) =>
    super

    # Not sure when event will not be defined, but parent
    # implementation takes that into the consideration
    if event
      @mousePosition =
        pageX: event.pageX
        pageY: event.pageY

  confirmSelection: (event) =>
    return true unless @selectedTargets.length is 1

    # event.previousMousePosition might not exist if checkForEndSelection was called manually without an event object
    # We ignore if mouse movement was to small to select really anything meaningful
    return false if event.previousMousePosition and Math.abs(event.previousMousePosition.pageX - event.pageX) <= 1 and Math.abs(event.previousMousePosition.pageY - event.pageY) <= 1

    quote = @plugins.TextAnchors.getQuoteForTarget @selectedTargets[0]
    # Quote should be a non-empty string
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

    @deselectAllHighlights()

    return # Make sure CoffeeScript does not return anything
