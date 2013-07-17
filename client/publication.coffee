Deps.autorun ->
  if Session.get 'currentPublicationId'
    Meteor.subscribe 'publications-by-id', Session.get 'currentPublicationId'
    Meteor.subscribe 'annotations-by-publication', Session.get 'currentPublicationId'
    Meteor.subscribe 'comments-by-publication', Session.get 'currentPublicationId'

# This function should work on rotated elements as well for all values
getElementPosition = (element) ->
  dims =
    left: 0
    top: 0
    right: 0
    bottom: 0
    width: 0
    height: 0

  if element
    rect = element.getBoundingClientRect()
    parentRect = $(element).parent().get(0).getBoundingClientRect()
    dims.left = rect.left - parentRect.left
    dims.top = rect.top - parentRect.top
    dims.right = rect.right - parentRect.right
    dims.bottom = rect.bottom - parentRect.bottom

    if rect.width
      dims.width = rect.width
      dims.height = rect.height
    else
      dims.width = dims.right - dims.left
      dims.height = dims.bottom - dims.top

  dims

normalizeStartEnd = (start, end) ->
  [Math.min(start, end), Math.max(start, end)]

removeTemporaryAnnotation = ->
  $highlightedAnnotation = $('#viewer .display .annotations .highlighted')
  if $.trim($highlightedAnnotation.text()) is "Enter annotation"
    annotation = $highlightedAnnotation.data 'annotation'
    Annotations.remove annotation._id if annotation

hideHiglight = ($textLayer, dontRemove) ->
  $textLayer.children().removeClass 'highlighted'

  removeTemporaryAnnotation() unless dontRemove

showHighlight = ($textLayer, start, end, dontRemove) ->
  hideHiglight $textLayer, dontRemove

  return if start is -1 or end is -1

  [start, end] = normalizeStartEnd start, end

  $textLayer.children().slice(start, end + 1).addClass 'highlighted'

findClosestElement = ($textLayer, position) ->
  closestDistance = Number.MAX_VALUE
  closestElementIndex = -1

  $textLayer.children().each (i, element) ->
    elementPosition = $(element).data 'position'

    distanceXLeft = position.left - elementPosition.left
    distanceXRight = position.left - (elementPosition.left + elementPosition.width)

    distanceYTop = position.top - elementPosition.top
    distanceYBottom = position.top - (elementPosition.top + elementPosition.height)

    distanceX = if Math.abs(distanceXLeft) < Math.abs(distanceXRight) then distanceXLeft else distanceXRight
    if position.left > elementPosition.left and position.left < elementPosition.left + elementPosition.width
      distanceX = 0

    distanceY = if Math.abs(distanceYTop) < Math.abs(distanceYBottom) then distanceYTop else distanceYBottom
    if position.top > elementPosition.top and position.top < elementPosition.top + elementPosition.height
      distanceY = 0

    distance = distanceX * distanceX + distanceY * distanceY
    if distance < closestDistance
      closestDistance = distance
      closestElementIndex = i

  closestElementIndex

openHihglight = (publication, page, $textLayer, start, end) ->
  return if start is -1 or end is -1

  [start, end] = normalizeStartEnd start, end

  annotationExists = Annotations.find(
    publication: publication._id
    location:
      page: page.pageNumber
      start: start
      end: end
  ).count()

  if not annotationExists
    Annotations.insert
      publication: publication._id
      body: "Enter annotation"
      location:
        page: page.pageNumber
        start: start
        end: end

  Session.set 'currentHighlight',
    page: page.pageNumber
    start: start
    end: end

closeHighlight = (publication, page, $textLayer) ->
  hideHiglight $textLayer

  Session.set 'currentHighlight', null

setupTextSelection = (publication, page, $textLayer) ->
  highlightStartPosition = null
  highlightStartIndex = -1
  highlightEndIndex = -1

  $textLayer.mousemove (e) ->
    return if highlightStartIndex is -1

    offset = $textLayer.offset()
    highlightEndIndex = findClosestElement $textLayer,
      left: e.pageX - offset.left
      top: e.pageY - offset.top

    return if highlightEndIndex is -1

    showHighlight $textLayer, highlightStartIndex, highlightEndIndex

  $textLayer.mousedown (e) ->
    offset = $textLayer.offset()
    highlightStartPosition =
      left: e.pageX - offset.left
      top: e.pageY - offset.top
    highlightStartIndex = findClosestElement $textLayer, highlightStartPosition

  $textLayer.mouseup (e) ->
    return if highlightStartIndex is -1

    offset = $textLayer.offset()
    if highlightStartPosition.left is e.pageX - offset.left and highlightStartPosition.top is e.pageY - offset.top
      closeHighlight publication, page, $textLayer
    else
      openHihglight publication, page, $textLayer, highlightStartIndex, highlightEndIndex

    highlightStartPosition = null
    highlightStartIndex = -1
    highlightEndIndex = -1

  $textLayer.mouseleave (e) ->
    return if highlightStartIndex is -1

    hideHiglight $textLayer

    highlightStartPosition = null
    highlightStartIndex = -1
    highlightEndIndex = -1

displayPublication = (publication) ->
  PDFJS.getDocument(publication.url()).then (pdf) ->
    for pageNumber in [1..pdf.numPages]
      $canvas = $('<canvas/>').addClass('display-canvas')
      $pageDisplay = $('<div/>').addClass('display-page').append($canvas).appendTo('#viewer .display-wrapper')

      do ($canvas, $pageDisplay) ->
        pdf.getPage(pageNumber).then (page) ->
          scale = 1.25
          viewport = page.getViewport scale
          context = $canvas.get(0).getContext '2d'

          $canvas.attr
            height: viewport.height
            width: viewport.width

          $textLayer = $('<div/>').addClass('display-text').css(
            height: viewport.height + 'px'
            width: viewport.width + 'px'
          # Disable text selection in various ways
          ).attr(
            unselectable: 'on'
          ).css(
            'user-select': 'none'
            '-moz-user-select': 'none'
            '-khtml-user-select': 'none'
            '-webkit-user-select': 'none'
          ).on('selectstart', false).appendTo $pageDisplay

          setupTextSelection publication, page, $textLayer

          page.getTextContent().then (textContent) ->
            textLayerOptions = 
              textLayerDiv: $textLayer.get(0)
              pageIndex: page.pageNumber - 1

            textLayer = new PDFJS.TextLayerBuilder textLayerOptions
            textLayer.setTextContent textContent

            renderContext =
              canvasContext: context
              viewport: viewport
              textLayer: textLayer

            page.render(renderContext).then ->
              $textLayer.children().each ->
                $(@).data
                  position: getElementPosition @

Deps.autorun ->
  publication = Publications.findOne Session.get 'currentPublicationId'

  return unless publication

  unless Session.equals 'currentPublicationSlug', publication.slug
    Meteor.Router.to Meteor.Router.publicationPath publication._id, publication.slug
    return

  # Maybe we don't yet have whole publication object available
  try
    unless publication.url()
      return
  catch e
    return

  displayPublication publication

# TODO: Destroy/clear pdf.js structures/memory on autorun cycle/stop

Template.publication.publication = ->
  Publications.findOne Session.get 'currentPublicationId'

Template.publication.comments = ->
  Comments.find
    publication: Session.get 'currentPublicationId'

Template.publicationAnnotations.annotations = ->
  Annotations.find
    publication: Session.get 'currentPublicationId'
  ,
    sort: [
      ['location.page', 'asc']
      ['location.start', 'asc']
      ['location.end', 'asc']
    ]

updateAnnotation = (id, template) ->
  Annotations.update id, $set: body: $(template.find '.text').text(), ->
    Deps.afterFlush ->
      $(template.find '.text').focus()

updateAnnotation = _.debounce updateAnnotation, 3000

Template.publicationAnnotationsItem.events =
  'keyup .text': (e, template) ->
    updateAnnotation @_id, template

  'blur .text': (e, template) ->
    Annotations.update @_id, $set: body: $(template.find '.text').text()

  'mouseenter .annotation': (e, template) ->
    currentHighlight = true
    unless _.isEqual Session.get('currentHighlight'), @location
      Session.set 'currentHighlight', null
      currentHighlight = false

    showHighlight $('#viewer .display .display-text').eq(@location.page - 1), @location.start, @location.end, currentHighlight

  'mouseleave .annotation': (e, template) ->
    unless _.isEqual Session.get('currentHighlight'), @location
      hideHiglight $('#viewer .display .display-text')

  'click .annotation': (e, template) ->
    currentHighlight = true
    unless _.isEqual Session.get('currentHighlight'), @location
      Session.set 'currentHighlight', @location
      currentHighlight = false

    showHighlight $('#viewer .display .display-text').eq(@location.page - 1), @location.start, @location.end, currentHighlight

Template.publicationAnnotationsItem.highlighted = ->
  currentHighlight = Session.get 'currentHighlight'

  currentHighlight?.page is @location.page and currentHighlight?.start is @location.start and currentHighlight?.end is @location.end

Template.publicationAnnotationsItem.rendered = ->
  $(@findAll('.annotation')).data
    annotation: @data

Template.publicationEntry.displayDay = (time) ->
  moment(time).format 'MMMM Do YYYY'

Template.publicationEntry.events =
  'click .preview-link': (e, template) ->
    e.preventDefault()
    Meteor.subscribe 'publications-by-id', @_id, ->
      Deps.afterFlush ->
        $(template.find '.abstract').slideToggle(200)
