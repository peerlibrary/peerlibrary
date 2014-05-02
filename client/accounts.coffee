Template._loginButtonsLoggedInSingleLogoutButton.displayName = Template._loginButtonsLoggedInDropdown.displayName = ->
  Meteor.person()?.displayName()

changingPasswordInResetPassword = false
changingPasswordInEnrollAccount = false

# To close sign in buttons dialog box when clicking, focusing or pressing a key somewhere outside
$(document).on 'click focus keypress', (e) ->
  # originalEvent is defined only for native events, but we are triggering
  # click manually as well, so originalEvent is not always defined
  unless e.originalEvent?.accountsDialogBoxEvent
    Accounts._loginButtonsSession.closeDropdown()
    Accounts._loginButtonsSession.set 'resetPasswordToken', null
    Accounts._loginButtonsSession.set 'enrollAccountToken', null
    changingPasswordInResetPassword = false
    changingPasswordInEnrollAccount = false
  return # Make sure CoffeeScript does not return anything

# But if clicked inside, we mark the event so that dialog box is not closed
Template._loginButtons.events
  'click #login-buttons, focus #login-buttons, keypress #login-buttons': (e, template) ->
    e.accountsDialogBoxEvent = true
    return # Make sure CoffeeScript does not return anything

$(document).on 'keyup', (e) ->
  if e.keyCode is 27 # Escape key
    Accounts._loginButtonsSession.closeDropdown()
    Accounts._loginButtonsSession.set 'resetPasswordToken', null
    Accounts._loginButtonsSession.set 'enrollAccountToken', null
    changingPasswordInResetPassword = false
    changingPasswordInEnrollAccount = false
  return # Make sure CoffeeScript does not return anything

# Don't allow dropping files while password reset is in progress
Template._resetPasswordDialog.events
  'dragover': (e, template) ->
    e.preventDefault()
    return # Make sure CoffeeScript does not return anything

  'dragleave': (e, template) ->
    e.preventDefault()
    return # Make sure CoffeeScript does not return anything

  'drop .hide-background': (e, template) ->
    e.stopPropagation()
    e.preventDefault()
    return # Make sure CoffeeScript does not return anything

  'click .accounts-centered-dialog, focus .accounts-centered-dialog, keypress .accounts-centered-dialog': (e, template) ->
    e.accountsDialogBoxEvent = true
    return # Make sure CoffeeScript does not return anything

  'click #login-buttons-reset-password-button': (e, template) ->
    changingPasswordInResetPassword = true
    return # Make sure CoffeeScript does not return anything

  'keypress #reset-password-new-password': (e, template) ->
    changingPasswordInResetPassword = true if event.keyCode is 13 # Enter key
    return # Make sure CoffeeScript does not return anything

  'click #login-buttons-cancel-reset-password': (e, template) ->
    changingPasswordInResetPassword = false
    return # Make sure CoffeeScript does not return anything

Template._resetPasswordDialog.rendered = ->
  Meteor.defer =>
    $(@findAll '#reset-password-new-password').focus()

# When password is reset or reset is canceled, we change the location to the index page
lastResetPasswordToken = null
Deps.autorun ->
  resetPasswordToken = Accounts._loginButtonsSession.get 'resetPasswordToken'
  if resetPasswordToken is null and lastResetPasswordToken
    Notify.success "Password reset." if changingPasswordInResetPassword
    Meteor.Router.toNew Meteor.Router.indexPath()
  lastResetPasswordToken = resetPasswordToken
  changingPasswordInResetPassword = false

# Don't allow dropping files while account enrollment is in progress
Template._enrollAccountDialog.events
  'dragover': (e, template) ->
    e.preventDefault()
    return # Make sure CoffeeScript does not return anything

  'dragleave': (e, template) ->
    e.preventDefault()
    return # Make sure CoffeeScript does not return anything

  'drop .hide-background': (e, template) ->
    e.stopPropagation()
    e.preventDefault()
    return # Make sure CoffeeScript does not return anything

  'click .accounts-centered-dialog, focus .accounts-centered-dialog, keypress .accounts-centered-dialog': (e, template) ->
    e.accountsDialogBoxEvent = true
    return # Make sure CoffeeScript does not return anything

  'click #login-buttons-enroll-account-button': (e, template) ->
    changingPasswordInEnrollAccount = true
    return # Make sure CoffeeScript does not return anything

  'keypress #enroll-account-password': (e, template) ->
    changingPasswordInEnrollAccount = true if event.keyCode is 13 # Enter key
    return # Make sure CoffeeScript does not return anything

  'click #login-buttons-cancel-enroll-account': (e, template) ->
    changingPasswordInEnrollAccount = false
    return # Make sure CoffeeScript does not return anything

Template._enrollAccountDialog.rendered = ->
  Meteor.defer =>
    $(@findAll '#enroll-account-password').focus()

# When user enrolls or enrollment is canceled, we change the location to the index page
lastEnrollAccountToken = null
Deps.autorun ->
  enrollAccountToken = Accounts._loginButtonsSession.get 'enrollAccountToken'
  if enrollAccountToken is null and lastEnrollAccountToken
    Notify.success "Password set." if changingPasswordInEnrollAccount
    Meteor.Router.toNew Meteor.Router.indexPath()
  lastEnrollAccountToken = enrollAccountToken
  changingPasswordInEnrollAccount = false

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

Template._loginButtonsLoggedInDropdownActions.events
  'click .invite-button': (e, template) ->
    # Return if not a normal click (maybe user wants to open a link in a tab)
    return if e.altKey or e.ctrlKey or e.metaKey or e.shiftKey
    return unless e.which is 1 # Left mouse button

    e.preventDefault()
    Session.set 'inviteDialogActive', true
    Session.set 'inviteDialogError', null
    $('#invite-dialog-email').val('')

    Accounts._loginButtonsSession.closeDropdown()

    Meteor.setTimeout =>
      $('#invite-dialog-email').focus()
    , 100 # ms

    return # Make sure CoffeeScript does not return anything

  'click .invite-button, focus .invite-button, keypress .invite-button': (e, template) ->
    e.inviteDialogBoxEvent = true
    return # Make sure CoffeeScript does not return anything

Template.inviteDialog.displayed = ->
  Session.get 'inviteDialogActive'

Template.inviteDialog.waiting = ->
  Session.get 'inviteDialogSending'

Template.inviteDialog.inviteError = ->
  Session.get 'inviteDialogError'

# To close newsletter dialog box when clicking, focusing, or pressing a key somewhere outside
$(document).on 'click focus keypress', (e) ->
  # originalEvent is defined only for native events, but we are triggering
  # click manually as well, so originalEvent is not always defined
  Session.set 'inviteDialogActive', false unless e.originalEvent?.inviteDialogBoxEvent
  return # Make sure CoffeeScript does not return anything

$(document).on 'keyup', (e) ->
  Session.set 'inviteDialogActive', false if e.keyCode is 27 # Escape key
  return # Make sure CoffeeScript does not return anything

# But if clicked inside, we mark the event so that dialog box is not closed
Template.inviteDialog.events
# We have to bind directly to invite-dialog to intercept click on the parent
# element of all and not directly on child elements. For example, when input is
# disabled, its click handler is not called, but invite-dialog handler is.
  'click .invite-dialog, focus .invite-dialog, keypress .invite-dialog': (e, template) ->
    e.inviteDialogBoxEvent = true
    return # Make sure CoffeeScript does not return anything

  'submit .invite-send': (e, template) ->
    e.preventDefault()
    return if Session.get 'inviteDialogSending'
    Session.set 'inviteDialogSending', true

    email = $(template.findAll '#invite-dialog-email').val()

    Meteor.call 'invite-user', email, (error) =>
      Session.set 'inviteDialogSending', false

      if error
        Session.set 'inviteDialogError', (error.reason or "Unknown error.")

        # Refocus for user to correct an error
        Meteor.setTimeout =>
          $(template.findAll '#invite-dialog-email').focus()
        , 10 # ms

      else
        Session.set 'inviteDialogError', null
        Session.set 'inviteDialogActive', false

        Notify.success "User #{ email } invited."

      return # Make sure CoffeeScript does not return anything

