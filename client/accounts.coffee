@inviteUser = (email, message, onSuccess, onError) ->
  Meteor.call 'invite-user', email, (message or ''), (error, newPersonId) =>
    if error
      showNotification = if onError then onError error else true
      Notify.fromError error, true if showNotification
      return

    showNotification = if onSuccess then onSuccess newPersonId else true
    Notify.success "User #{ email } invited.", "We have created an account and sent them an invitation email with a link to set their password." if showNotification

Template._loginButtonsLoggedInSingleLogoutButton.displayName = Template._loginButtonsLoggedInDropdown.displayName = ->
  Meteor.person(displayName: 1)?.getDisplayName()

changingPasswordInResetPassword = false
changingPasswordInEnrollAccount = false

# To close sign in buttons dialog box when clicking, focusing or pressing a key somewhere outside
$(document).on 'click focus keypress', (event) ->
  # Do not act when interacting with notifications
  return if $(event.target).closest('.notifications').length

  # originalEvent is defined only for native events, but we are triggering
  # click manually as well, so originalEvent is not always defined
  unless event.originalEvent?.accountsDialogBoxEvent
    Accounts._loginButtonsSession.closeDropdown()
    Accounts._loginButtonsSession.set 'resetPasswordToken', null
    Accounts._loginButtonsSession.set 'enrollAccountToken', null
    changingPasswordInResetPassword = false
    changingPasswordInEnrollAccount = false
  return # Make sure CoffeeScript does not return anything

# But if clicked inside, we mark the event so that dialog box is not closed
Template._loginButtons.events
  'click #login-buttons, focus #login-buttons, keypress #login-buttons': (event, template) ->
    event.accountsDialogBoxEvent = true
    return # Make sure CoffeeScript does not return anything

# Autofocus username when login form is rendered
Template._loginButtonsLoggedOutPasswordService.rendered = ->
  $('#login-username-or-email').focus()

# Autofocus e-mail when forgot password form is rendered
Template._forgotPasswordForm.rendered = ->
  $('#forgot-password-email').focus()

$(document).on 'keyup', (event) ->
  if event.keyCode is 27 # Escape key
    Accounts._loginButtonsSession.closeDropdown()
    Accounts._loginButtonsSession.set 'resetPasswordToken', null
    Accounts._loginButtonsSession.set 'enrollAccountToken', null
    changingPasswordInResetPassword = false
    changingPasswordInEnrollAccount = false
  return # Make sure CoffeeScript does not return anything

# Don't allow dropping files while password reset is in progress
Template._resetPasswordDialog.events
  'dragover, dragleave': (event, template) ->
    event.preventDefault()
    return # Make sure CoffeeScript does not return anything

  'drop .hide-background': (event, template) ->
    event.stopPropagation()
    event.preventDefault()
    return # Make sure CoffeeScript does not return anything

  'click .accounts-centered-dialog, focus .accounts-centered-dialog, keypress .accounts-centered-dialog': (event, template) ->
    event.accountsDialogBoxEvent = true
    return # Make sure CoffeeScript does not return anything

  'click #login-buttons-reset-password-button': (event, template) ->
    changingPasswordInResetPassword = true
    return # Make sure CoffeeScript does not return anything

  'keypress #reset-password-new-password': (event, template) ->
    changingPasswordInResetPassword = true if event.keyCode is 13 # Enter key
    return # Make sure CoffeeScript does not return anything

  'click #login-buttons-cancel-reset-password': (event, template) ->
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
  'dragover, dragleave': (event, template) ->
    event.preventDefault()
    return # Make sure CoffeeScript does not return anything

  'drop .hide-background': (event, template) ->
    event.stopPropagation()
    event.preventDefault()
    return # Make sure CoffeeScript does not return anything

  'click .accounts-centered-dialog, focus .accounts-centered-dialog, keypress .accounts-centered-dialog': (event, template) ->
    event.accountsDialogBoxEvent = true
    return # Make sure CoffeeScript does not return anything

  'click #login-buttons-enroll-account-with-username-button': (event, template) ->
    event.preventDefault()
    enrollAccount()
    return # Make sure CoffeeScript does not return anything

  'keypress #enroll-account-with-username-password': (event, template) ->
    enrollAccount() if event.keyCode is 13 # Enter key
    return # Make sure CoffeeScript does not return anything

  # The rest of the cancel button functionality is handled by Meteor
  'click #login-buttons-cancel-enroll-account': (event, template) ->
    changingPasswordInEnrollAccount = false
    return # Make sure CoffeeScript does not return anything

Template._enrollAccountDialog.rendered = ->
  Meteor.defer =>
    $(@findAll '#enroll-account-with-username-username').focus()

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

enrollAccount = ->
  changingPasswordInEnrollAccount = true

  username = $('#enroll-account-with-username-username').val()
  password = $('#enroll-account-with-username-password').val()

  token = Accounts._loginButtonsSession.get 'enrollAccountToken'
  Accounts.resetPasswordWithUsername token, password, username, (error) ->
    if error
      Accounts._loginButtonsSession.errorMessage error.reason or error.toString?() or "Unknown error"
    else
      Accounts._loginButtonsSession.set 'enrollAccountToken', null

# We extend Meteor's Accounts.resetPassword functionality with username so that
# user must choose username in the enroll form
Accounts.resetPasswordWithUsername = (token, password, username, callback) ->
  try
    throw new Meteor.Error 400, "Invalid token." unless token
    User.validateUsername username
    User.validatePassword password

    verifier = SRP.generateVerifier password
    Accounts.callLoginMethod
      methodName: 'reset-password-with-username'
      methodArguments: [token, verifier, username]
      userCallback: callback
  catch error
    callback error
