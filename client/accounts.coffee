Template.displayIcon.userIconUrl = ->
  # TODO: We should specify default URL to the image of an avatar which is generated from name initials
  "https://secure.gravatar.com/avatar/#{ Meteor.person()?.gravatarHash }?s=24"

Template._loginButtonsLoggedInDropdownActions.personSlug = ->
  Meteor.person()?.slug

Template._loginButtonsLoggedInSingleLogoutButton.displayName = ->
  Meteor.person()?.displayName()

Template._loginButtonsLoggedInDropdown.displayName = Template._loginButtonsLoggedInSingleLogoutButton.displayName

# To close sign in buttons dialog box when clicking, focusing or pressing a key somewhere outside
$(document).on 'click focus keypress', (e) ->
  # originalEvent is defined only for native events, but we are triggering
  # click manually as well, so originalEvent is not always defined
  Accounts._loginButtonsSession.closeDropdown() unless e.originalEvent?.accountsDialogBoxEvent
  return # Make sure CoffeeScript does not return anything

# But if clicked inside, we mark the event so that dialog box is not closed
Template._loginButtons.events
  'click #login-buttons, focus #login-buttons, keypress #login-buttons': (e, template) ->
    e.accountsDialogBoxEvent = true
    return # Make sure CoffeeScript does not return anything

$(document).on 'keyup', (e) ->
  Accounts._loginButtonsSession.closeDropdown() if e.keyCode is 27 # Escape key
  return # Make sure CoffeeScript does not return anything

Handlebars.registerHelper 'currentUserId', (options) ->
  Meteor.userId()

lastPersonId = Meteor.personId()

Deps.autorun ->
  return if Meteor.loggingIn()

  personId = Meteor.personId()
  if personId isnt lastPersonId
    if personId
      Notify.success "Signed in."
    else
      Notify.success "Signed out."
    lastPersonId = personId
