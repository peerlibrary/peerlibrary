WHITESPACE_REGEX = /\s+/g

class @Annotator.Plugin.TextAnchors extends Annotator.Plugin.TextAnchors
  checkForEndSelection: (event={}) =>
    event.previousMousePosition = @annotator.mousePosition
    @annotator.mousePosition = null

    super event

class @Annotator extends Annotator
  mousePosition: null

  constructor: (@_highlighter) ->
    super null,
      noScan: true
    delete @options.noScan

  _setupViewer: =>
    # Overridden and disabled

  _setupDynamicStyle: =>
    # Overridden and disabled

  startViewerHideTimer: =>
    # Overridden and disabled

  clearViewerHideTimer: =>
    # Overridden and disabled

  _setupWrapper: =>
    @wrapper = $(document)

  _setupDocumentEvents: =>
    $(document).on 'mousedown': (e) =>
      @checkForStartSelection e if e.which is 1 # Left mouse button
      return # Make sure CoffeeScript does not return anything

    @

  checkForStartSelection: (event) =>
    super

    @mousePosition =
      pageX: event.pageX
      pageY: event.pageY

  confirmSelection: (event) =>
    return true unless @selectedTargets.length is 1

    return false if event.previousMousePosition and Math.abs(event.previousMousePosition.pageX - event.pageX) <= 1 and Math.abs(event.previousMousePosition.pageY - event.pageY) <= 1

    quote = @plugins.TextAnchors.getQuoteForTarget @selectedTargets[0]
    # Quote should be non-empty string
    return false unless quote

    # Quote should not be empty when we remove all whitespace
    return false unless quote.replace(WHITESPACE_REGEX, '')

    true

  onSuccessfulSelection: (event, immediate) =>
    # Store the selected targets
    @selectedTargets = event.targets

    return false unless @confirmSelection event

    time = new Date().valueOf()

    annotation = @createAnnotation()

    # Extract the quotation and serialize the ranges
    annotation = @setupAnnotation annotation

    console.log "Time (s):", (new Date().valueOf() - time) / 1000

    # TODO: Do something with annotation
    console.log annotation

    true
