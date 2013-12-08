class @Annotator extends Annotator
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

  onSuccessfulSelection: (event, immediate) =>
    time = new Date().valueOf()

    # Store the selected targets
    @selectedTargets = event.targets

    annotation = @createAnnotation()

    # Extract the quotation and serialize the ranges
    annotation = @setupAnnotation annotation

    console.log "Time (s):", (new Date().valueOf() - time) / 1000

    # TODO: Do something with annotation
    console.log annotation
