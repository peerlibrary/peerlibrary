Template.accessIcon.iconName = ->
  switch @access
    when Publication.ACCESS.OPEN then 'icon-public'
    when Publication.ACCESS.CLOSED then 'icon-closed'
    when Publication.ACCESS.PRIVATE then 'icon-private'
    else assert false

Template.accessText.open = ->
  @access is Publication.ACCESS.OPEN

Template.accessText.closed = ->
  @access is Publication.ACCESS.CLOSED

Template.accessText.private = ->
  @access is Publication.ACCESS.PRIVATE

Template.accessDescription.open = Template.accessText.open
Template.accessDescription.closed = Template.accessText.closed
Template.accessDescription.private = Template.accessText.private

Template.member.documentIsPerson = ->
  @ instanceof Person

Template.member.documentIsGroup = ->
  @ instanceof Group

Template.memberAdd.documentIsPerson = Template.member.documentIsPerson
Template.memberAdd.documentIsGroup = Template.member.documentIsGroup

Template.memberAdd.noLinkDocument = ->
  # When inline item is used inside a button, disable its hyperlink. We don't want an active link
  # inside a button, because the button itself provides an action that happens when clicking on it.

  # Because we cannot access parent templates we're modifying the data with an extra parameter
  # TODO: Change when Meteor allows accessing parent context
  @noLink = true
  @

@EnableCatalogItemLink = (template) ->
  template.events
    'mousedown': (event, template) ->
      # Save mouse position so we can later detect selection actions in click handler
      template.data._previousMousePosition =
        pageX: event.pageX
        pageY: event.pageY

      # Allow user to right click the link
      return if event.button is 2

      # Temporarily hide the link to allow selection
      $(template.find '.full-item-link').hide()

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
