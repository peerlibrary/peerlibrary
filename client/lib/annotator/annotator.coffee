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

  # $displayWrapper will be saved in _setupWrapper to @wrapper
  constructor: (@_highlighter, $displayWrapper) ->
    super $displayWrapper,
      noScan: true
    delete @options.noScan

    @_annotations = {}
    @selectedAnnotationId = null

  destroy: =>
    $(document).off '.annotator'
    $(@wrapper).off '.annotator'

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

  _inAnyHighlight: (clientX, clientY) =>
    for highlight in @getHighlights()
      return true if highlight.in clientX, clientY

    false

  _inAnySelectedHighlight: (clientX, clientY) =>
    for highlight in @getHighlights() when highlight.isSelected()
      return true if highlight.in clientX, clientY

    false

  _setupDocumentEvents: =>
    # Overridden

    $(document).on 'mousedown.annotator': (e) =>
      # Left mouse button and mousedown happened on a target inside a display-page
      # (We have mousedown evente handler on document to be able to always deselect,
      # but then we have to manually determine if event target is inside a display-page)
      if e.which is 1 and $(e.target).closest('.display-page').length
        inAnySelectedHighlight = @_inAnySelectedHighlight e.clientX, e.clientY

        # If mousedown happened outside any selected highlight, we deselect highlights,
        # but we leave location unchanged so that on a new possible new highlight we
        # update location to the new location without going through a publication-only
        # location. If no highlight is made we update location in onFailedSelection.
        @_deselectAllHighlights() unless inAnySelectedHighlight

        # To be able to correctly deselect in mousemove handler
        @mouseStartingInsideSelectedHighlight = inAnySelectedHighlight

        @checkForStartSelection e

      # Left mouse button and mousedown happened on an annotation
      else if e.which is 1 and $(e.target).closest('.annotations-list .annotation').length
        # If mousedown happened inside an annotation, we deselect highlights,
        # but we leave location unchanged so that we update location to the
        # annotation location without going through a publication-only location.
        @_deselectAllHighlights()

      else
        # Otherwise we deselect everything
        @_selectHighlight null

      return # Make sure CoffeeScript does not return anything

    $(document).on 'mousemove.annotator': (e) =>
      # We started moving for a new selection, so deselect any selected highlight
      if @mouseIsDown and @mouseStartingInsideSelectedHighlight
        # To deselect only at the first mousemove event, otherwise any (new) selection would be impossible
        @mouseStartingInsideSelectedHighlight = false

        @_deselectAllHighlights()

      return # Make sure CoffeeScript does not return anything

    @ # For chaining

  # Just a helper function, to really deselect call _selectHighlight(null)
  _deselectAllHighlights: =>
    highlight.deselect() for highlight in @getHighlights()

  updateLocation: =>
    # This is our annotations
    annotationId = Session.get 'currentAnnotationId'
    # @selectedAnnotationId is Annotator's annotation, so our highlights
    if @selectedAnnotationId
      Meteor.Router.toNew Meteor.Router.highlightPath Session.get('currentPublicationId'), Session.get('currentPublicationSlug'), @selectedAnnotationId
    else if annotationId
      Meteor.Router.toNew Meteor.Router.annotationPath Session.get('currentPublicationId'), Session.get('currentPublicationSlug'), annotationId
    else
      Meteor.Router.toNew Meteor.Router.publicationPath Session.get('currentPublicationId'), Session.get('currentPublicationSlug')

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
    @_deselectAllHighlights()

    # And re-select it as a selected highlight
    # This just draws it selected and does not yet update location
    # We do this re-selection to make sure selection matches stored selection
    highlight.select() for highlight in @getHighlights [annotation]

    # TODO: Optimize time it takes to create a new highlight, for example, if you select whole PDF page it takes quite some time (> 1s) currently
    #console.log "Time (s):", (new Date().valueOf() - time) / 1000

    @_insertHighlight annotation

    return # Make sure CoffeeScript does not return anything

  onFailedSelection: (event) =>
    super

    # If this was not triggered by a user event (but by calling checkForEndSelection
    # after enableAnnotating event) and thus does not have previousMousePosition, we
    # do not do anything. Otherwise if location contains highlight and we want to
    # have it selected when the page loads, this would not happen because onFailedSelection
    # would be called which would deselect the highlight below.
    return if not event or not event.previousMousePosition

    # If click (mousedown coordinates same as mouseup coordinates) is on a highlight, we do not
    # do anything because click event will be made as well, which will select the new highlight.
    # This assures we do not first deselect (and update location to publication location) just
    # to select another highlight immediately afterwards (and update location again to highlight).
    return if event.previousMousePosition.pageX - event.pageX == 0 and event.previousMousePosition.pageY - event.pageY == 0 and @_inAnyHighlight event.clientX, event.clientY

    # Otherwise we deselect any existing selected highlight
    @_selectHighlight null

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

    setHighlights @_getRenderedHighlights()

    annotation

  deleteAnnotation: (annotation) ->
    # Deselecting before calling super so that all highlight objects are still available
    @_selectHighlight null if annotation._id is @selectedAnnotationId

    annotation = super

    delete @_annotations[annotation._id]

    setHighlights @_getRenderedHighlights()

    annotation

  _realizePage: (index) =>
    super

    setHighlights @_getRenderedHighlights()

    return # Make sure CoffeeScript does not return anything

  _virtualizePage: (index) =>
    super

    setHighlights @_getRenderedHighlights()

    return # Make sure CoffeeScript does not return anything

  ############################################################################
  # We are using Annotator's annotations as highlights, so while annotation  #
  # objects inside Annotator's code are annotations, from the perspective of #
  # PeerLibrary highlighter they are highlights. All API functions from here #
  # on are to bridge PeerLibrary highlighter with Annotator. They get        #
  # highlighter documents from PeerLibrary and map them to Annotator's       #
  # annotations.                                                             #
  ############################################################################

  _highlightAdded: (id, fields) =>
    fields._id = id
    @setupAnnotation fields

  _highlightChanged: (id, fields) =>
    # TODO: What if target changes on existing annotation? How we update Annotator's annotation so that anchors and its highligts are moved?
    # TODO: Do we have to call setHighlights in updateAnnotation?

    annotation = _.extend @_annotations[id], fields
    @updateAnnotation annotation

  _highlightRemoved: (id) =>
    annotation = @_annotations[id]
    @deleteAnnotation annotation if annotation

  _insertHighlight: (annotation) =>
    # Populate with some of our fields
    annotation.author =
      _id: Meteor.personId()
    annotation.publication =
      _id: Session.get 'currentPublicationId'
    annotation.highlights = []

    # Remove fields we do not want to store into the database
    highlight = _.pick annotation, '_id', 'author', 'publication', 'quote', 'target'
    highlight.target = _.map highlight.target, (t) =>
      _.pick t, 'source', 'selector'

    Highlights.insert highlight, (error, id) =>
      # Meteor triggers removal if insertion was unsuccessful, so we do not have to do anything
      if error
        Notify.meteorError error, true
        return

      # TODO: Should we update also other fields (like full author, created timestamp)
      # TODO: Should we force redraw of opened highlight control if it was opened while we still didn't have _id and other fields?

      # Finally select it (until now it was just drawn selected) and update location
      @_selectHighlight id

    annotation

  _removeHighlight: (id) =>
    Highlights.remove id, (error) =>
      Notify.meteorError error, true if error

  _selectHighlight: (id) =>
    if id and @_annotations[id]
      @selectedAnnotationId = id

      highlights = @getHighlights [@_annotations[id]]
      otherHighlights = _.difference @getHighlights(), highlights

      highlight.deselect() for highlight in otherHighlights when highlight.isSelected()
      # highlights is an empty list if Annotator's anchors for selected Annotator's
      # annotation (our highlight) are not realized (Annotator's highlights created),
      # but we do not care because we set selectedAnnotationId and highlight will be
      # selected when it is finally created in _createHighlight.
      highlight.select() for highlight in highlights when not highlight.isSelected()

      annotation = createAnnotationDocument()
      annotation.local = true
      annotation.highlights = [
        _id: id
      ]

      LocalAnnotations.remove
        local: true
      LocalAnnotations.insert annotation

      # On click on the highlight we are for sure inside the highlight, so we can
      # immediatelly send a mouse enter event to make sure related annotation has
      # a hovered state. Even if _selectHighlight not really happened because of
      # a click, it is still a nice effect to emphasize the invitation.
      Meteor.defer ->
        $('.annotations-list .annotation').trigger 'highlightMouseenter', [id]

    else
      @selectedAnnotationId = null

      @_deselectAllHighlights()

      LocalAnnotations.remove
        local: true

    # We might not be called from _highlightLocationHandle autorun, so make sure location matches selected highlight
    @updateLocation()

  _getRenderedHighlights: =>
    highlights = {}
    for highlight in @getHighlights()
      if highlights[highlight.annotation._id]
        highlights[highlight.annotation._id].push highlight.getBoundingBox()
      else
        highlights[highlight.annotation._id] = [highlight.getBoundingBox()]
    highlights
