WHITESPACE_REGEX = /\s+/g

class @Annotator.Plugin.TextAnchors extends Annotator.Plugin.TextAnchors
  checkForEndSelection: (event) =>
    # Just to be sure we reset the variable
    @mouseStartingInsideSelectedHighlight = false

    # checkForEndSelection is called without an event object after the enableAnnotating
    # event, but we are not really using that (calling things manually instead, based on
    # how/when publication is renderes) so we don't do anything. This also fixes occasional
    # duplication of a highlight if it was in the URL and got selected on page load, calling
    # checkForEndSelection sometimes then duplicates it and creates a new one.
    return unless event

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

    # We have out own UI for adding annotations, so we remove Annotator's
    @adder.remove()

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

    $(document).on 'mousedown.annotator': (event) =>
      # Left mouse button and mousedown happened on a target inside a display-page
      # (We have mousedown evente handler on document to be able to always deselect,
      # but then we have to manually determine if event target is inside a display-page)
      if event.which is 1 and $(event.target).closest('.display-page').length
        inAnySelectedHighlight = @_inAnySelectedHighlight event.clientX, event.clientY

        # If mousedown happened outside any selected highlight, we deselect highlights,
        # but we leave location unchanged so that on a new possible new highlight we
        # update location to the new location without going through a publication-only
        # location. If no highlight is made we update location in onFailedSelection.
        @_deselectAllHighlights() unless inAnySelectedHighlight

        # To be able to correctly deselect in mousemove handler
        @mouseStartingInsideSelectedHighlight = inAnySelectedHighlight

        @checkForStartSelection event

      # Left mouse button and mousedown happened on an annotation
      else if event.which is 1 and $(event.target).closest('.annotations-list .annotation').length
        # If mousedown happened inside an annotation, we deselect highlights,
        # but we leave location unchanged so that we update location to the
        # annotation location without going through a publication-only location.
        @_deselectAllHighlights()

      else
        # Otherwise we deselect everything
        @_selectHighlight null

      return # Make sure CoffeeScript does not return anything

    $(document).on 'mousemove.annotator': (event) =>
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

  _addHighlightToEditor: (highlightId) =>
    body = Template.highlightPromptInEditor(_id: highlightId).trim()

    count = LocalAnnotation.documents.update
      local: LocalAnnotation.LOCAL.AUTOMATIC
      'publication._id': Session.get 'currentPublicationId'
      # Do not set a new body if annotation is in the process of editing (even if user has not yet changed anything)
      editing:
        $exists: false
    ,
      $set:
        body: body

    $('.annotations-list .annotation.local .annotation-content-editor').html(body) if count

  _removeHighlightFromEditor: (highlightId) =>
    count = LocalAnnotation.documents.update
      local: LocalAnnotation.LOCAL.AUTOMATIC
      'publication._id': Session.get 'currentPublicationId'
      # We make a simple check for the highlight ID because it is not really possible
      # for some other ID to appear in our highlightPromptInEditor template and match
      body: new RegExp "#{ highlightId }"
      # If user is editing an annotation, we leave it be (this is consistent with
      # us not updating or removing links to highlights, which are removed, from other
      # existing annotations)
      editing:
        $exists: false
    ,
      $set:
        body: ''

    $('.annotations-list .annotation.local .annotation-content-editor').html('') if count

  updateLocation: =>
    # This is our annotations
    annotationId = Session.get 'currentAnnotationId'
    commentId = Session.get 'currentCommentId'
    # @selectedAnnotationId is Annotator's annotation, so our highlights
    if @selectedAnnotationId
      Meteor.Router.toNew Meteor.Router.highlightPath Session.get('currentPublicationId'), Session.get('currentPublicationSlug'), @selectedAnnotationId
    else if annotationId
      Meteor.Router.toNew Meteor.Router.annotationPath Session.get('currentPublicationId'), Session.get('currentPublicationSlug'), annotationId
    else if commentId
      Meteor.Router.toNew Meteor.Router.commentPath Session.get('currentPublicationId'), Session.get('currentPublicationSlug'), commentId
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
    # TODO: We currently support only when there is one selected target
    return false unless @selectedTargets.length is 1

    # event.previousMousePosition might not exist if checkForEndSelection was called manually without
    # an event object. We ignore if mouse movement was to small to select really anything meaningful.
    return false if event.previousMousePosition and Math.abs(event.previousMousePosition.pageX - event.pageX) <= 1 and Math.abs(event.previousMousePosition.pageY - event.pageY) <= 1

    quote = @getQuoteForTarget? @selectedTargets[0]
    # Quote should be a non-empty string
    return false unless quote

    # Quote should not be empty when we remove all whitespace
    return false unless quote.replace(WHITESPACE_REGEX, '')

    true

  canCreateHighlight: =>
    # Enough is to check if user is logged in. Check if user has read
    # access to the publication content is made on the server side.
    Meteor.personId()

  onSuccessfulSelection: (event, immediate) =>
    assert event
    assert event.segments

    # Describe the selection with targets
    @selectedTargets = (@_getTargetFromSelection s for s in event.segments)

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

    # Highlights are a special case and we make _id on the client
    annotation._id = Random.id()

    annotation

  hasAnnotation: (id) ->
    id of @_annotations

  setupAnnotation: (annotation) ->
    # We transform the Annotator's annotation into PeerLibrary highlight document.
    # Read below for more information on how we are using Annotator's annotations
    # as highlights.
    annotation = new Highlight annotation

    annotation = super annotation

    @_annotations[annotation._id] = annotation

    currentHighlights.set @_getRenderedHighlights()

    annotation

  deleteAnnotation: (annotation) ->
    # Deselecting before calling super so that all highlight objects are still available
    @_selectHighlight null if annotation._id is @selectedAnnotationId

    # If the highlight is by chance currently automatically linked in local editor, remove it
    @_removeHighlightFromEditor annotation._id

    annotation = super

    delete @_annotations[annotation._id]

    currentHighlights.set @_getRenderedHighlights()

    annotation

  _realizePage: (index) =>
    super

    currentHighlights.set @_getRenderedHighlights()

    return # Make sure CoffeeScript does not return anything

  _virtualizePage: (index) =>
    super

    currentHighlights.set @_getRenderedHighlights()

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
    # TODO: Do we have to call currentHighlights.set in updateAnnotation? Currently we are ignoring values, only comparing keys when setting highlights

    annotation = _.extend @_annotations[id], fields
    @updateAnnotation annotation

  _highlightRemoved: (id) =>
    annotation = @_annotations[id]
    @deleteAnnotation annotation if annotation

  _insertHighlight: (annotation) =>
    target = _.map annotation.target, (t) =>
      _.pick t, 'source', 'selector'

    # Highlights are a special case and we provide _id from the client
    Meteor.call 'create-highlight', Session.get('currentPublicationId'), annotation._id, annotation.quote, target, (error, highlightId) =>
      # TODO: Does Meteor triggers removal if insertion was unsuccessful, so that we do not have to do anything?
      return Notify.smartError error, true if error

      assert.equal annotation._id, highlightId

      # TODO: Should we update also other fields (like full author, createdAt timestamp)
      # TODO: Should we force redraw of opened highlight control if it was opened while we still didn't have _id and other fields?

      # Finally select it (until now it was just drawn selected) and update location
      @_selectHighlight highlightId

    annotation

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

      # Add reference to annotation
      @_addHighlightToEditor id

      # On click on the highlight we are for sure inside the highlight, so we can
      # immediately send a mouse enter event to make sure related annotation has
      # a hovered state. Even if _selectHighlight not really happened because of
      # a click, it is still a nice effect to emphasize the invitation.
      Meteor.defer ->
        $('.annotations-list .annotation').trigger 'highlightMouseenter', [id]

    else
      @selectedAnnotationId = null

      @_deselectAllHighlights()

    # We might not be called from _highlightLocationHandle autorun, so make sure location matches selected highlight
    @updateLocation()

  _getRenderedHighlights: =>
    highlights = {}
    for highlight in @getHighlights()
      boundingBox = highlight.getBoundingBox()
      # Sometimes when rendering highlight coordinates are not yet known so we skip those highlights
      continue unless _.isFinite(boundingBox.left) and _.isFinite(boundingBox.top)
      if highlights[highlight.annotation._id]
        highlights[highlight.annotation._id].push boundingBox
      else
        highlights[highlight.annotation._id] = [boundingBox]
    for highlightId, boundingBoxes of highlights
      # We sort to assure array order does not change if values do not change,
      # so that reactive variable change is not triggered, if there is only
      # difference in highlights order returned by getHighlights
      highlights[highlightId] = boundingBoxes.sort (a, b) ->
        if a.left isnt b.left
          a.left - b.left
        else if a.top isnt b.top
          a.top - b.top
        else if a.width isnt b.width
          a.width - b.width
        else if a.height isnt b.height
          a.height - b.height
        else
          0
    highlights
