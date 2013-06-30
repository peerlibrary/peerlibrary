Deps.autorun ->
  Meteor.subscribe 'publications-by-id', Session.get 'currentPublicationId'
  Meteor.subscribe 'notes-by-publication-and-paragraph', Session.get('currentPublicationId'), Session.get('currentDiscussionParagraph')
  Meteor.subscribe 'comments-by-publication-and-paragraph', Session.get('currentPublicationId'), Session.get('currentDiscussionParagraph')

Deps.autorun ->
  publication = Publications.findOne Session.get 'currentPublicationId'

  return unless publication

  PDFJS.getDocument(publication.url()).then (pdf) ->
    for pageNumber in [1..pdf.numPages]
      $canvas = $('<canvas/>').addClass('display-canvas')
      $pageDisplay = $('<div/>').addClass('display-page').append($canvas).appendTo('#viewer .display')

      do ($canvas, $pageDisplay) ->
        pdf.getPage(pageNumber).then (page) ->
          scale = 0.75
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

          outputScale = getOutputScale();
          if outputScale.scaled
            cssScale = "scale(#{ 1 / outputScale.sx }, #{1 / outputScale.sy})";
            CustomStyle.setProp 'transform', canvas, cssScale
            CustomStyle.setProp 'transformOrigin', canvas, '0% 0%'
            if $textLayerDiv.get(0)
              CustomStyle.setProp 'transform', $textLayerDiv.get(0), cssScale
              CustomStyle.setProp 'transformOrigin', $textLayerDiv.get(0), '0% 0%'

          context._scaleX = outputScale.sx
          context._scaleY = outputScale.sy
          if outputScale.scaled
            context.scale outputScale.sx, outputScale.sy

          page.getTextContent().then (textContent) ->

            textLayer = new TextLayerBuilder $textLayerDiv.get(0), page.number - 1
            textLayer.setTextContent textContent

            renderContext =
              canvasContext: context
              viewport: viewport
              textLayer: textLayer

            page.render(renderContext).then ->
              for paragraph, i in publication.paragraphs or [] when paragraph.page is page.pageNumber
                do (i) ->
                  $('<div/>').addClass('paragraph').css(
                    left: paragraph.left * scale + 'px'
                    top: paragraph.top * scale + 'px'
                    width: paragraph.width * scale + 'px'
                    height: paragraph.height * scale + 'px'
                  ).appendTo($pageDisplay).click (e) ->
                    Session.set 'currentDiscussionParagraph', i
                    Session.set 'displayDiscussion', true

Template.publication.publication = ->
  Publications.findOne Session.get 'currentPublicationId'

Template.publication.notes = ->
  Notes.findOne
    publication: Session.get 'currentPublicationId'
    paragraph: Session.get 'currentDiscussionParagraph'

Template.publication.comments = ->
  Comments.find
    publication: Session.get 'currentPublicationId'
    paragraph: Session.get 'currentDiscussionParagraph'

Template.publication.paragraphNumber = ->
  Session.get 'currentDiscussionParagraph'

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

Template.publication.displayTimeAgo = (time) ->
  moment(time).fromNow()

postComment = (e) ->
  if Meteor.user()
    Comments.insert
      created: new Date()
      author:
        username: Meteor.user().username
        fullName: Meteor.user().profile.firstName + ' ' + Meteor.user().profile.lastName
        id: Meteor.user()._id
      body: $('.comment-input').val()
      parent: null
      publication: Session.get 'currentPublicationId'
      paragraph: Session.get 'currentDiscussionParagraph'
    , ->
      $('.comment-input').val ''
  else
    Meteor.Router.to('/login')

Template.publicationItem.displayDay = (time) ->
  moment(time).format 'MMMM Do YYYY'
