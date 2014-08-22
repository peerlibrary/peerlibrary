Template.member.documentIsPerson = ->
  @ instanceof Person

Template.member.documentIsGroup = ->
  @ instanceof Group

Template.memberAdd.documentIsPerson = Template.member.documentIsPerson
Template.memberAdd.documentIsGroup = Template.member.documentIsGroup

Template.memberAdd.created = ->
  # By default, have links clickable.
  @addLink = true

Template.memberAdd.noLinkDocument = ->
  # When inline item is used inside a button, disable its hyperlink. We don't want an active link
  # inside a button, because the button itself provides an action that happens when clicking on it.

  # Because we cannot access parent templates we're modifying the data with an
  # extra parameter
  # TODO: Change when Meteor allows accessing parent context
  @addLink = false
  @

@EnableCatalogItemLink = (template) ->
  template.events
    'mousedown': (event, template) ->
      # Save mouse position so we can later detect selection actions in click handler
      template.data._previousMousePosition =
        pageX: event.pageX
        pageY: event.pageY

      # Temporarily hide the link to allow selection
      $(template.find '.full-item-link').hide()

      if event.button is 2
        # On right clicks, determine if user was trying to interact with selection or the link.
        # If user didn't right click on an item that holds some part of the selection, show the
        # link again so they can get a context menu for the link instead.
        underMouse = document.elementFromPoint event.clientX, event.clientY
        $(template.find '.full-item-link').show() unless rangy.getSelection().containsNode underMouse, true

    'mouseup': (event, template) ->
      # Don't redirect if user interacted with one of the actionable controls or a link on the item
      $target = $(event.target)
      return if $target.closest('.actionable').length > 0 or $target.closest('a').length > 0

      # Don't redirect if this might have been a selection
      event.previousMousePosition = template.data._previousMousePosition
      return if event.previousMousePosition and (Math.abs(event.previousMousePosition.pageX - event.pageX) > 1 or Math.abs(event.previousMousePosition.pageY - event.pageY) > 1)

      # Redirect user to the publication
      Meteor.Router.toNew template.data.path()

# To make sure catalog item links are always restored we show them on any mouseup
$(document).mouseup ->
  $('.full-item-link').show()
