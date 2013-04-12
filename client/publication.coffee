do -> # To not pollute the namespace
  Deps.autorun ->
    Meteor.subscribe 'publications-by-id', Session.get 'currentPublicationId'
    Meteor.subscribe 'comments-by-publication-and-paragraph', Session.get('currentPublicationId'), 0
    Meteor.subscribe 'summaries-by-publication-and-paragraph', Session.get('currentPublicationId'), 0
    Session.set 'currentDiscussionParagraph', 0

  Template.publication.publication = ->
    Publications.findOne Session.get 'currentPublicationId'

  Template.publication.summary = ->
    Summaries.findOne
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
      Session.set 'tempSummary', $('.paragraph-summary').text()
      placeCaretAtEnd document.getElementById 'summary'
      $('.paragraph-summary').addClass 'active'
      $('.edit-options').hide()
      $('.save-options').fadeIn 200
    'click .cancel-link': (e) ->
      e.preventDefault()
      $('.paragraph-summary').html Session.get 'tempSummary'
      $('.paragraph-summary').removeClass 'active'
      $('div[contentEditable="true"]').blur()
      $('.save-options').hide()
      $('.edit-options').fadeIn 200
    'click .save-link': (e) ->
      e.preventDefault()
      Session.set 'tempSummary', $('.paragraph-summary').text()
      $('.paragraph-summary').removeClass 'active'
      $('div[contentEditable="true"]').blur()
      $('.save-options').hide()
      $('.edit-options').fadeIn 200
    'focus .paragraph-summary': (e) ->
      $(this).addClass 'active'
      $('.edit-options').hide()
      $('.save-options').fadeIn 200
    'click .thread-link': (e) ->
      e.preventDefault()
      $('.details').hide()
      $('.threads-wrap').hide()
      $('.discussion').fadeIn 250
      $('.single-thread').fadeIn()

  Template.publication.events publicationEvents

  Template.publication.rendered = ->
    $('.discussion').hide()

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
        editableFix = $('<input style="width:1px;height:1px;border:none;margin:0;padding:0;" tabIndex="-1">').appendTo '.paragraph-summary'
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

    $('.paragraph-summary').focus ->
      $(this).addClass 'active'
      $('.edit-options').hide()
      $('.save-options').fadeIn 200

    $('.paragraph-summary').blur ->
      $(this).removeClass 'active'

    $('.comment-input').css('overflow', 'hidden').autogrow()

  Template.publicationItem.displayDay = (time) ->
    moment(time).format 'MMMM Do YYYY'

  Template.publication.displayTimeAgo = (time) ->
    moment(time).fromNow()