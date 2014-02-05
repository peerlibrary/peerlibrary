Template.displayIcon.userIconUrl = ->
  # TODO: We should specify default URL to the image of an avatar which is generated from name initials
  "https://secure.gravatar.com/avatar/#{ Meteor.person()?.gravatarHash }?s=24"

Template._loginButtonsLoggedInDropdownActions.personSlug = ->
  Meteor.person()?.slug

# To close sign in buttons dialog box when clicking or focusing somewhere outside
$(document).click (e) ->
  # originalEvent is defined only for native events, but we are triggering
  # click manually as well, so originalEvent is not always defined
  Accounts._loginButtonsSession.closeDropdown() unless e.originalEvent?.dialogBoxEvent
  return # Make sure CoffeeScript does not return anything

$(document).focus (e) ->
  # originalEvent is defined only for native events, but we are triggering
  # click manually as well, so originalEvent is not always defined
  Accounts._loginButtonsSession.closeDropdown() unless e.originalEvent?.dialogBoxEvent
  return # Make sure CoffeeScript does not return anything

# But if clicked inside, we mark the event so that dialog box is not closed
Template._loginButtons.events
  'click #login-buttons': (e, template) ->
    e.dialogBoxEvent = true
    return # Make sure CoffeeScript does not return anything

  'focus #login-buttons': (e, template) ->
    e.dialogBoxEvent = true
    return # Make sure CoffeeScript does not return anything

Handlebars.registerHelper 'currentUserId', (options) ->
  Meteor.userId()

lastPersonId = Meteor.personId()

Deps.autorun ->
  return if Meteor.loggingIn()

  personId = Meteor.personId()
  if personId isnt lastPersonId
    if personId
      Notify.success "Signed in successfully."
    else
      Notify.success "Signed out successfully."
    lastPersonId = personId
