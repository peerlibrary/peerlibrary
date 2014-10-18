usernameFormMessages = new FormMessages()
usernameLastValue = null
usernameReadyForValidation = false
usernameFieldModified = false
usernameSubmitted = false

passwordFormMessages = new FormMessages()
currentPasswordLastValue = null
newPasswordLastValue = null
newPasswordReadyForValidation = false
newPasswordFieldModified = false

backgroundFormMessages = new FormMessages()

resetUsernameForm = ->
  usernameFormMessages.resetMessages()
  usernameLastValue = null
  usernameReadyForValidation = false
  usernameFieldModified = false

resetPasswordForm = (template) ->
  passwordFormMessages.resetMessages()
  if template
    template.$('input.current-password').val('')
    template.$('input.new-password').val('')
  else
    $('input.current-password').val('')
    $('input.new-password').val('')
  currentPasswordLastValue = null
  newPasswordLastValue = null
  newPasswordReadyForValidation = false
  newPasswordFieldModified = false

resetBackgroundForm = ->
  backgroundFormMessages.resetMessages()

# Reset forms when settings page becomes active
Tracker.autorun ->
  if Session.get 'settingsActive'
    resetUsernameForm()
    resetPasswordForm()
    resetBackgroundForm()

# Username settings
Template.settingsUsername.events
  'submit form.set-username': (event, template) ->
    event.preventDefault()

    usernameFormMessages.resetMessages()
    username = template.$('input.username').val()

    usernameFormMessages.setErrorMessage 'Username is required.', 'username' unless username

    try
      User.validateUsername username, 'username'
    catch error
      usernameFormMessages.setError error

    if usernameFormMessages.isValid()
      usernameSubmitted = true
      Meteor.call 'set-username', username, (error) ->
        return usernameFormMessages.setError error if error
        resetUsernameForm()
        usernameFormMessages.setInfoMessage "Username set successfully."

    return # Make sure CoffeeScript does not return anything

  'blur input.username': (event, template) ->
    # We postpone blur event handling as a workaround for a bug in Meteor.
    # See https://github.com/peerlibrary/peerlibrary/pull/520#issuecomment-52514483
    # TODO: Move function below out of setTimeout when we move to Blaze
    # TODO: Remove flag usernameSubmitted and everything related to it
    Meteor.setTimeout ->
      usernameReadyForValidation = usernameFieldModified
      return if usernameSubmitted
      username = template.$('input.username').val()
      validateUsername username, 'username'
    ,
      100 # ms

    return # Make sure CoffeeScript does not return anything

  'keyup input.username, paste input.username': (event, template) ->
    # Proceed only if something really changed
    newValue = template.$('input.username').val()
    return if newValue is usernameLastValue
    usernameLastValue = newValue

    usernameFormMessages.resetMessages '' # Reset global messages

    usernameFieldModified = true
    username = template.$('input.username').val()
    validateUsername username, 'username'

    return # Make sure CoffeeScript does not return anything

  'focus input': (event, template) ->
    usernameSubmitted = false

    return # Make sure CoffeeScript does not return anything

Template.settingsUsername.helpers
  usernameExists: ->
    !!Meteor.person?('user.username': 1).user?.username

  messageOnField: (field) ->
    usernameFormMessages.get field

  validity: (field) ->
    return 'invalid' unless usernameFormMessages.isValid field

validateUsername = (username, messageField) ->
  return unless usernameReadyForValidation
  try
    User.validateUsername username, messageField
    usernameFormMessages.resetMessages messageField
  catch error
    usernameFormMessages.setError error

# Password settings
Template.settingsPassword.events
  'submit form.set-password': (event, template) ->
    event.preventDefault()

    newPasswordReadyForValidation = true
    passwordFormMessages.resetMessages()
    currentPassword = template.$('input.current-password').val()
    newPassword = template.$('input.new-password').val()

    passwordFormMessages.setErrorMessage "Current password is required.", 'current-password' unless currentPassword

    try
      User.validatePassword newPassword, 'new-password'
    catch error
      passwordFormMessages.setError error

    if passwordFormMessages.isValid()
      changePassword currentPassword, newPassword, (error) ->
        return passwordFormMessages.setError error if error
        resetPasswordForm template
        passwordFormMessages.setInfoMessage "Password changed successfully."

    return # Make sure CoffeeScript does not return anything

  'keyup input.current-password, paste input.current-password': (event, template) ->
    # Proceed only if something really changed
    newValue = template.$('input.current-password').val()
    return if newValue is currentPasswordLastValue
    currentPasswordLastValue = newValue

    passwordFormMessages.resetMessages '' # Reset global messages

    # We cannot verify validity of the password on the client, so
    # let's at least remove any error message to not confuse the user
    # with a message that password is still invalid. In other fields
    # we are providing feedback immediately, so we have to keep this
    # the same. We cannot say that field is invalid if in fact maybe
    # it is not. Better to err on the side of validity than saying that
    # something is wrong when it is valid.
    passwordFormMessages.resetMessages 'current-password'

    return # Make sure CoffeeScript does not return anything

  'blur input.new-password': (event, template) ->
    newPasswordReadyForValidation = newPasswordFieldModified
    newPassword = template.$('input.new-password').val()
    validatePassword newPassword, 'new-password'

    return # Make sure CoffeeScript does not return anything

  'keyup input.new-password, paste input.new-password': (event, template) ->
    # Proceed only if something really changed
    newValue = template.$('input.new-password').val()
    return if newValue is newPasswordLastValue
    newPasswordLastValue = newValue

    passwordFormMessages.resetMessages '' # Reset global messages

    newPasswordFieldModified = true
    newPassword = template.$('input.new-password').val()
    validatePassword newPassword, 'new-password'

    return # Make sure CoffeeScript does not return anything

Template.settingsPassword.helpers
  messageOnField: (field) ->
    passwordFormMessages.get field

  validity: (field) ->
    return 'invalid' unless passwordFormMessages.isValid field

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

  # We check this manually because changePassword error throws global 'Match failed' error if current password is empty string
  return callback new ValidationError "Current password is required.", 'current-password' unless currentPassword

  Accounts.changePassword currentPassword, newPassword, (error) ->
    formError = new ValidationError (error.reason or error.toString() or "Unknown error"), 'current-password' if error
    callback formError

Template.settingsBackground.helpers
  checked: ->
    backgroundPaused = !!Meteor.user().settings?.backgroundPaused
    # We also clear messages here so that if a settings change comes from somewhere else
    # (like from the index page) any shown messages are cleared as well. The idea is that
    # if what is displayed is different from what it should be then we clear messages.
    # In normal workflow checkbox is always first set, then method is called, and then this
    # helper is rerun when value changes, so checkbox should already be set, so messages stay.
    backgroundFormMessages.resetMessages() if backgroundPaused isnt $('input.paused').is(':checked')
    backgroundPaused

Template.settingsBackground.helpers
  messageOnField: (field) ->
    backgroundFormMessages.get field

Template.settingsBackground.events
  'change input.paused': (event, template) ->
    event.preventDefault()

    checked = template.$('input.paused').is(':checked')
    try
      backgroundFormMessages.resetMessages()
      Meteor.call 'pause-background', checked, (error) ->
        if error
          template.$('input.paused').prop('checked', !!Meteor.user().settings?.backgroundPaused)
          return backgroundFormMessages.setError error
        resetBackgroundForm()
        backgroundFormMessages.setInfoMessage if checked then "Background paused." else "Background resumed."
    catch error
      backgroundFormMessages.setError error

    return # Make sure CoffeeScript does not return anything
