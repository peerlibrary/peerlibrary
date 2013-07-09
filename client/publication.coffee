Deps.autorun ->
  if Session.get 'currentPublicationId'
    Meteor.subscribe 'publications-by-id', Session.get 'currentPublicationId'
    Meteor.subscribe 'annotations-by-publication', Session.get 'currentPublicationId'
    Meteor.subscribe 'comments-by-publication', Session.get 'currentPublicationId'

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

          $pageDisplay.attr
            height: viewport.height
            width: viewport.width

          $textLayerDiv = $('<div/>')
            .addClass('display-text')
            .css("height", viewport.height + "px")
            .css("width", viewport.width + "px")
            .appendTo($pageDisplay)

          $pageDisplay.css("position","relative");

          $closestTextDiv = null
          closestDistance = Number.MAX_VALUE;

          $textLayerDiv.mousemove (e) ->
            layerOffset = $(this).offset()
            relX = e.pageX - layerOffset.left
            relY = e.pageY - layerOffset.top

            closestDistance = Number.MAX_VALUE;
            $textLayerDiv.children().each ->
              textDivOffset = $(this).data("cachedOffset")
              textDivWidth = $(this).data("cachedWidth")
              textDivHeight = $(this).data("cachedHeight")

              distXLeft = relX - textDivOffset.left
              distXRight = relX - (textDivOffset.left + textDivWidth)
              distXCenter = relX - (textDivOffset.left + textDivWidth/2.0)

              distYTop = relY - textDivOffset.top
              distYBottom = relY - (textDivOffset.top + textDivHeight)
              distYCenter = relY - (textDivOffset.top + textDivHeight/2.0)


              distX = if Math.abs(distXLeft) < Math.abs(distXRight) then distXLeft else distXRight
              if relX > textDivOffset.left and relX < textDivOffset.left + textDivWidth
                distX = 0

              distY = if Math.abs(distYTop) < Math.abs(distYBottom) then distYTop else distYBottom
              if relY > textDivOffset.top and relY < textDivOffset.top + textDivHeight
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

          $textLayerDiv
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
          #   if $textLayerDiv.get(0)
          #     CustomStyle.setProp 'transform', $textLayerDiv.get(0), cssScale
          #     CustomStyle.setProp 'transformOrigin', $textLayerDiv.get(0), '0% 0%'
          
          # context._scaleX = outputScale.sx
          # context._scaleY = outputScale.sy
          # if outputScale.scaled
          #   context.scale outputScale.sx, outputScale.sy

          page.getTextContent().then (textContent) ->

            textLayerOptions = 
              textLayerDiv: $textLayerDiv.get(0)
              pageIndex: page.number - 1

            textLayer = new PDFJS.TextLayerBuilder textLayerOptions
            textLayer.setTextContent textContent

            renderContext =
              canvasContext: context
              viewport: viewport
              textLayer: textLayer

            page.render(renderContext).then ->
              $textLayerDiv.children().each ->
                $(this).data("cachedOffset", $(this).position())
                $(this).data("cachedWidth", $(this).width())
                $(this).data("cachedHeight", $(this).height())

# TODO: Destroy/clear pdf.js structures/memory on autorun cycle/stop

Template.publication.publication = ->
  Publications.findOne Session.get 'currentPublicationId'

Template.publication.comments = ->
  Comments.find
    publication: Session.get 'currentPublicationId'

publicationEvents =
  #TODO: click .details-link, .discussion-link
  'click .details-link': (e) ->
    e.preventDefault()
    Session.set 'displayDiscussion', false
    Session.set 'currentDiscussionParagraph', null
    $('.discussion').hide()
    $('.details').fadeIn 250
  'click .discussion-link': (e) ->
    e.preventDefault()
    $('.details').hide()
    $('.discussion').fadeIn 250
  'click .journal-link': (e) ->
    $('.pub-info').slideToggle 'fast'
  'click .thread-item': (e) ->
    e.preventDefault()
    $('.threads-wrap').hide()
    $('.single-thread').fadeIn()
  'click .all-discussions': (e) ->
    e.preventDefault()
    $('.single-thread').hide()
    $('.threads-wrap').fadeIn()
  'click .edit-link': (e) ->
    e.preventDefault()
    Session.set 'tempNotes', $('.paragraph-notes').text()
    placeCaretAtEnd document.getElementById 'notes'
    $('.paragraph-notes').addClass 'active'
    $('.edit-options').hide()
    $('.save-options').fadeIn 200
  'click .cancel-link': (e) ->
    e.preventDefault()
    $('.paragraph-notes').html Session.get 'tempNotes'
    $('.paragraph-notes').removeClass 'active'
    $('div[contentEditable="true"]').blur()
    $('.save-options').hide()
    $('.edit-options').fadeIn 200
  'click .save-link': (e) ->
    e.preventDefault()
    Session.set 'tempNotes', $('.paragraph-notes').text()
    $('.paragraph-notes').removeClass 'active'
    $('div[contentEditable="true"]').blur()
    $('.save-options').hide()
    $('.edit-options').fadeIn 200
  'focus .paragraph-notes': (e) ->
    $(this).addClass 'active'
    $('.edit-options').hide()
    $('.save-options').fadeIn 200
  'click .comment-submit': (e) ->
    e.preventDefault()
    postComment e

Template.publication.events publicationEvents

Template.publication.rendered = ->
  if Session.get 'displayDiscussion'
    $('.details').hide()
    $('.discussion').fadeIn()
    $('.single-thread').fadeIn()

Template.publication.created = ->
  #select end of contenteditable true entity
  setEndOfContenteditable = (contentEditableElement) ->
    if document.createRange #Firefox, Chrome, Opera, Safari, IE 9+
      range = document.createRange() #Create a range (a range is a like the selection but invisible)
      range.selectNodeContents contentEditableElement #Select the entire contents of the element with the range
      range.collapse false #collapse the range to the end point. false means collapse to end rather than the start
      selection = window.getSelection() #get the selection object (allows you to change selection)
      selection.removeAllRanges() #remove any selections already made
      selection.addRange range #make the range you have just created the visible selection
    else if document.selection #IE 8 and lower
      range = document.body.createTextRange() #Create a range (a range is a like the selection but invisible)
      range.moveToElementText contentEditableElement #Select the entire contents of the element with the range
      range.collapse false #collapse the range to the end point. false means collapse to end rather than the start
      range.select() #Select the range (make it the visible selection

  $ ->
    # WebKit contentEditable focus bug workaround:
    if /AppleWebKit\/([\d.]+)/.exec navigator.userAgent
      editableFix = $('<input style="width:1px;height:1px;border:none;margin:0;padding:0;" tabIndex="-1">').appendTo '.paragraph-notes'
      $('[contenteditable]').blur ->
        editableFix[0].setSelectionRange 0, 0
        editableFix.blur()

  placeCaretAtEnd = (el) ->
    el.focus()
    if (typeof window.getSelection != "undefined") and (typeof document.createRange != "undefined")
      range = document.createRange()
      range.selectNodeContents el
      range.collapse false
      sel = window.getSelection()
      sel.removeAllRanges()
      sel.addRange range
    else if typeof document.body.createTextRange != "undefined"
      textRange = document.body.createTextRange()
      textRange.moveToElementText el
      textRange.collapse false
      textRange.select()

  $('.paragraph-notes').focus ->
    $(this).addClass 'active'
    $('.edit-options').hide()
    $('.save-options').fadeIn 200

  $('.paragraph-notes').blur ->
    $(this).removeClass 'active'

  $('.comment-input').css('overflow', 'hidden').autogrow()

#Template.publication.displayTimeAgo = (time) ->
#  moment(time).fromNow()

#postComment = (e) ->
#  if Meteor.user()
#    Comments.insert
#      created: new Date()
#      author:
#        username: Meteor.user().username
#        fullName: Meteor.user().profile.firstName + ' ' + Meteor.user().profile.lastName
#        id: Meteor.user()._id
#      body: $('.comment-input').val()
#      parent: null
#      publication: Session.get 'currentPublicationId'
#    , ->
#      $('.comment-input').val ''
#  else
#    Meteor.Router.to('/login')

Template.publicationItem.displayDay = (time) ->
  moment(time).format 'MMMM Do YYYY'

Template.publicationItem.events =
  'click .preview-link': (e, template) ->
    e.preventDefault()
    Meteor.subscribe 'publications-by-id', @_id, ->
      Deps.afterFlush ->
        $(template.find '.abstract').slideToggle(200)

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
