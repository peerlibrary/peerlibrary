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

findClosestElement = ($elements, position) ->
  closestDistance = Number.MAX_VALUE
  closestElementIndex = -1

  $elements.each (i, element) ->
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

setupTextSelection = (publication, page, $textLayer) ->
  highlightStartIndex = -1

  $textLayer.mousemove (e) ->
    return if highlightStartIndex is -1

    offset = $textLayer.offset()
    currentPosition =
      left: e.pageX - offset.left
      top: e.pageY - offset.top

    $elements = $textLayer.children()
    currentPositionIndex = findClosestElement $elements, currentPosition

    return if currentPositionIndex is -1

    $elements.css
      'background-color': 'rgba(0,0,0,0)'

    $highlight = $elements.slice Math.min(highlightStartIndex, currentPositionIndex), Math.max(highlightStartIndex, currentPositionIndex) + 1

    $highlight.css
      'background-color': 'rgba(255,0,0,0.3)'

  $textLayer.mousedown (e) ->
    offset = $textLayer.offset()
    highlightStartIndex = findClosestElement $textLayer.children(),
      left: e.pageX - offset.left
      top: e.pageY - offset.top

  $textLayer.mouseup (e) ->
    highlightStartIndex = -1

  $textLayer.mouseleave (e) ->
    highlightStartIndex = -1

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
              pageIndex: page.number - 1

            textLayer = new PDFJS.TextLayerBuilder textLayerOptions
            textLayer.setTextContent textContent

            renderContext =
              canvasContext: context
              viewport: viewport
              textLayer: textLayer

            page.render(renderContext).then ->
              $textLayer.children().each ->
                $(this).data
                  position: getElementPosition this

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

Template.publicationEntry.displayDay = (time) ->
  moment(time).format 'MMMM Do YYYY'

Template.publicationEntry.events =
  'click .preview-link': (e, template) ->
    e.preventDefault()
    Meteor.subscribe 'publications-by-id', @_id, ->
      Deps.afterFlush ->
        $(template.find '.abstract').slideToggle(200)
