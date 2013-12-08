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
    # Store the selected targets
    @selectedTargets = event.targets

    annotation = @createAnnotation()

    # Extract the quotation and serialize the ranges
    annotation = @setupAnnotation annotation

    # TODO: Do something with annotation
    console.log annotation
