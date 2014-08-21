usernameFormMessages = new FormMessages()
usernameReadyForValidation = false
usernameFieldModified = false
usernameSubmitted = false

passwordFormMessages = new FormMessages()
newPasswordReadyForValidation = false
newPasswordFieldModified = false

resetUsernameForm = ->
  usernameFormMessages.resetMessages()
  usernameReadyForValidation = false
  usernameFieldModified = false

resetPasswordForm = ->
  passwordFormMessages.resetMessages()
  $('#current-password').val('')
  $('#new-password').val('')
  newPasswordReadyForValidation = false
  newPasswordFieldModified = false

# Reset forms when settings page becomes active
Deps.autorun ->
  if Session.get 'settingsActive'
    resetUsernameForm()
    resetPasswordForm()

# Username settings
Template.settingsUsername.events =
  'submit form.set-username': (event, template) ->
    event.preventDefault()

    usernameSubmitted = true
    usernameFormMessages.resetMessages()
    username = $('#username').val()
    try
      usernameFormMessages.resetMessages()
      Meteor.call 'set-username', username, (error) ->
        return usernameFormMessages.setError error if error
        resetUsernameForm()
        usernameFormMessages.setInfoMessage "Username set successfully"
    catch error
      usernameFormMessages.setError error

    return # Make sure CoffeeScript does not return anything

  'blur input.username': (event, template) ->
    # We postpone blur event handling as a workaround for a bug in Meteor.
    # See https://github.com/peerlibrary/peerlibrary/pull/520#issuecomment-52514483
    # TODO: Move function below out of setTimeout when we move to Blaze
    # TODO: Remove flag usernameSubmitted and everything related to it
    Meteor.setTimeout ->
      usernameReadyForValidation = usernameFieldModified
      return if usernameSubmitted
      username = $('#username').val()
      validateUsername username, 'username'
    ,
      100 # ms

    return # Make sure CoffeeScript does not return anything

  'keyup input.username, paste input.username': (event, template) ->
    usernameFieldModified = true
    username = $('#username').val()
    validateUsername username, 'username'

    return # Make sure CoffeeScript does not return anything

  'focus input': (event, template) ->
    usernameSubmitted = false
    usernameFormMessages.resetMessages '' # Reset global messages

    return # Make sure CoffeeScript does not return anything

Template.settings.usernameExists = ->
  !!Meteor.person?('user.username': 1).user?.username

Template.settingsUsername.messageOnField = (field, options) ->
  field = null unless options
  usernameFormMessages.get field

Template.settingsUsername.isValid = (field, options) ->
  field = null unless options
  usernameFormMessages.isValid field

validateUsername = (username, messageField) ->
  return unless usernameReadyForValidation
  try
    User.validateUsername username, messageField
    usernameFormMessages.resetMessages messageField
  catch error
    usernameFormMessages.setError error

# Password settings
Template.settingsPassword.events =
  'submit form.set-password': (event, template) ->
    event.preventDefault()

    newPasswordReadyForValidation = true
    passwordFormMessages.resetMessages()
    currentPassword = $('#current-password').val()
    newPassword = $('#new-password').val()

    passwordFormMessages.setErrorMessage 'Current password is required.', 'current-password' unless currentPassword

    try
      User.validatePassword newPassword, 'new-password'
    catch error
      passwordFormMessages.setError error

    if passwordFormMessages.isValid()
      changePassword currentPassword, newPassword, (error) ->
        if error
          passwordFormMessages.setError error
        else
          resetPasswordForm()
          passwordFormMessages.setInfoMessage "Password changed successfully."

    return # Make sure CoffeeScript does not return anything

  'blur input.new-password': (event, template) ->
    newPasswordReadyForValidation = newPasswordFieldModified
    newPassword = $('#new-password').val()
    validatePassword newPassword, 'new-password'

    return # Make sure CoffeeScript does not return anything

  'keyup input.new-password, paste input.new-password': (event, template) ->
    newPasswordFieldModified = true
    newPassword = $('#new-password').val()
    validatePassword newPassword, 'new-password'

    return # Make sure CoffeeScript does not return anything

  'focus input': (event, template) ->
    passwordFormMessages.resetMessages '' # Reset global messages

    return # Make sure CoffeeScript does not return anything

Template.settingsPassword.messageOnField = (field, options) ->
  field = null unless options
  passwordFormMessages.get field

Template.settingsPassword.isValid = (field, options) ->
  field = null unless options
  passwordFormMessages.isValid field

validatePassword = (newPassword, messageField) ->
  return unless newPasswordReadyForValidation

  try
    User.validatePassword newPassword, messageField
    passwordFormMessages.resetMessages messageField
  catch error
    passwordFormMessages.setError error

changePassword = (currentPassword, newPassword, callback) ->
  try
    User.validatePassword newPassword, 'new-password'
  catch error
    callback error
    return

  try
    # We check this manually because changePassword error throws global 'Match failed' error if current password is empty string
    throw new ValidationError 400, "Incorrect password.", 'current-password' unless currentPassword
    Accounts.changePassword currentPassword, newPassword, (error) ->
      formError = new ValidationError (error.reason or error.toString() or "Unknown error"), 'current-password' if error
      callback formError
  catch error
    callback error
