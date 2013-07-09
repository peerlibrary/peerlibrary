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

setupTextSelection = (publication, page, $textLayer) ->
  $closestTextDiv = null
  closestDistance = Number.MAX_VALUE;

  $textLayer.mousemove (e) ->
    layerOffset = $(this).offset()
    relX = e.pageX - layerOffset.left
    relY = e.pageY - layerOffset.top

    closestDistance = Number.MAX_VALUE;
    $textLayer.children().each ->
      position = $(this).data 'position'

      distXLeft = relX - position.left
      distXRight = relX - (position.left + position.width)
      distXCenter = relX - (position.left + position.width/2.0)

      distYTop = relY - position.top
      distYBottom = relY - (position.top + position.height)
      distYCenter = relY - (position.top + position.height/2.0)

      distX = if Math.abs(distXLeft) < Math.abs(distXRight) then distXLeft else distXRight
      if relX > position.left and relX < position.left + position.width
        distX = 0

      distY = if Math.abs(distYTop) < Math.abs(distYBottom) then distYTop else distYBottom
      if relY > position.top and relY < position.top + position.height
        distY = 0
      # distY = if Math.abs(distY) < Math.abs(distYCenter) then distY else distYCenter

      dist = Math.sqrt(distX*distX + distY*distY)

      if (dist < closestDistance)
        closestDistance = dist
        $closestTextDiv = $(this)

      $(this).css("color","rgba(0,0,0,0)")
      $(this).css("background-color","rgba(0,0,0,0)")
      # $(this).css("color","rgba(0,0,0,#{ Math.max(1.0-dist/100,0) })")

    # $closestTextDiv.css("color","rgba(0,0,0,1.0)")
    return if $closestTextDiv is null
    $closestTextDiv.css("background-color","rgba(255,0,0,0.3)")
    $(this).data("closestTextDiv",$closestTextDiv)


  $startTextDiv = null
  $endTextDiv = null

  $textLayer
    .mousedown (e) ->
      e.preventDefault()
      return if not $closestTextDiv
      $startTextDiv = $closestTextDiv
    .mouseup (e) ->
      return if not $closestTextDiv
      $endTextDiv = $closestTextDiv

  # outputScale = getOutputScale();
  # if outputScale.scaled
  #   cssScale = "scale(#{ 1 / outputScale.sx }, #{1 / outputScale.sy})";
  #   CustomStyle.setProp 'transform', canvas, cssScale
  #   CustomStyle.setProp 'transformOrigin', canvas, '0% 0%'
  #   if $textLayer.get(0)
  #     CustomStyle.setProp 'transform', $textLayer.get(0), cssScale
  #     CustomStyle.setProp 'transformOrigin', $textLayer.get(0), '0% 0%'

  # context._scaleX = outputScale.sx
  # context._scaleY = outputScale.sy
  # if outputScale.scaled
  #   context.scale outputScale.sx, outputScale.sy

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
          ).appendTo $pageDisplay

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
