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

    @_annotations = {}

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
    @updateLocation()

  updateLocation: =>
    location = null
    for highlight in @getHighlights() when highlight.isSelected()
      location = highlight.updateLocation location

    # If location was not set, then highlight.updateLocation was never
    # called, so let's update location to publication path
    Meteor.Router.toNew Meteor.Router.publicationPath Session.get('currentPublicationId'), Session.get('currentPublicationSlug') unless location

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

  canCreateHighlight: =>
    Meteor.personId()

  onSuccessfulSelection: (event, immediate) =>
    assert event
    assert event.targets

    # Store the selected targets
    @selectedTargets = event.targets

    return unless @confirmSelection event

    return unless @canCreateHighlight()

    #time = new Date().valueOf()

    annotation = @createAnnotation()

    # Extract the quotation and serialize the ranges
    annotation = @setupAnnotation annotation

    # Remove existing selection (the one we just made)
    @deselectAllHighlights()

    # And re-select it as a selected highlight
    highlight.select() for highlight in @getHighlights [annotation]

    # TODO: Optimize time it takes to create a new highlight, for example, if you select whole PDF page it takes quite some time (> 1s) currently
    #console.log "Time (s):", (new Date().valueOf() - time) / 1000

    @_insertHighlight annotation

    return # Make sure CoffeeScript does not return anything

  onFailedSelection: (event) =>
    super

    @deselectAllHighlights()

    return # Make sure CoffeeScript does not return anything

  getHref: =>
    path = Meteor.Router.publicationPath Session.get('currentPublicationId'), Session.get('currentPublicationSlug')
    Meteor.absoluteUrl path.replace /^\//, '' # We have to remove leading / for Meteor.absoluteUrl

  createAnnotation: ->
    annotation = super

    annotation._id = Random.id()

    annotation

  hasAnnotation: (id) ->
    id of @_annotations

  setupAnnotation: (annotation) ->
    annotation = super

    @_annotations[annotation._id] = annotation

    annotation

  deleteAnnotation: (annotation) ->
    annotation = super

    delete @_annotations[annotation._id]

    annotation

  # We are using Annotator's annotations as highlights, so while
  # input is an annotation object, we store it as a highlight
  _insertHighlight: (annotation) =>
    # Populate with some of our fields
    annotation.author =
      _id: Meteor.personId()
    annotation.publication =
      _id: Session.get 'currentPublicationId'

    Highlights.insert _.pick(annotation, '_id', 'author', 'publication', 'quote', 'target'), (error, id) =>
      # Meteor triggers removal if insertion was unsuccessful, so we do not have to do anything
      throw error if error

      # TODO: Should we update also other fields (like full author, created timestamp)
      # TODO: Should we force redraw of opened highlight control if it was opened while we still didn't have _id and other fields?

      @updateLocation()

    annotation

  # We are using Annotator's annotations as highlights, so while
  # input is an annotation object, we store it as a highlight
  _addHighlight: (id, fields) =>
    fields._id = id
    @setupAnnotation fields

  # We are using Annotator's annotations as highlights, so while
  # input is an annotation object, we store it as a highlight
  _changeHighlight: (id, fields) =>
    # TODO: What if target changes on existing annotation? How we update Annotator's annotation so that anchors and its highligts are moved?

    annotation = _.extend @_annotations[id], fields
    @updateAnnotation annotation

  # We are using Annotator's annotations as highlights, so while
  # input is an annotation object, we store it as a highlight
  _removeHighlight: (id) =>
    annotation = @_annotations[id]
    @deleteAnnotation annotation if annotation
