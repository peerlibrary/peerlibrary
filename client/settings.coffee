# Session variables wrapper for info/error messages
SettingsSession =
  _set: (prefix, key, value) ->
    Session.set prefix + key, value

  _get: (prefix, key) ->
    Session.get prefix + key

  # Returns object containing both info and error messages
  get: (prefix) ->
    throw new Error 'Prefix not set' unless prefix
    return {} =
      errorMessage: @errorMessage prefix
      infoMessage: @infoMessage prefix

  # Resets both info and error messages
  resetMessages: (prefix) ->
    throw new Error 'Prefix not set' unless prefix
    @_set prefix + 'InfoMessage', ''
    @_set prefix + 'ErrorMessage', ''

  # Sets error message from message argument or
  # returns error message if message argument is not set
  errorMessage: (prefix, message) ->
    throw new Error 'Prefix not set' unless prefix
    return @_get prefix, 'ErrorMessage' unless message
    @_set prefix, 'InfoMessage', ''
    @_set prefix, 'ErrorMessage', message

  # Sets info message from message argument or
  # returns info message if message argument is not set
  infoMessage: (prefix, message) ->
    throw new Error 'Prefix not set' unless prefix
    return @_get prefix, 'InfoMessage' unless message
    @_set prefix, 'ErrorMessage', ''
    @_set prefix, 'InfoMessage', message

# Clear messages when settings page becomes active
Deps.autorun ->
  if Session.get 'settingsActive'
    SettingsSession.resetMessages 'settingsUsername'
    SettingsSession.resetMessages 'settingsPassword'

Template.settings.person = ->
  Meteor.person()

# Username settings
Template.settingsUsername.events =
  'click button.set-username': (event, template) ->
    SettingsSession.resetMessages 'settingsUsername'
    event.preventDefault()
    username = $('#username').val()
    Meteor.call 'set-username', username, (error) ->
      SettingsSession.errorMessage 'settingsUsername', error.reason if error
      SettingsSession.infoMessage 'settingsUsername', "Username set successfully" unless error

    return # Make sure CoffeeScript does not return anything

Template.settings.usernameNotSet = ->
  !Meteor.person().user?.username

Template.settingsUsername.messages = ->
  SettingsSession.get 'settingsUsername'

# Password settings
Template.settingsPassword.events =
  'click button.change-password': (event, template) ->
    SettingsSession.resetMessages 'settingsPassword'
    event.preventDefault()
    currentPassword = $('#current-password').val()
    newPassword = $('#new-password').val()
    newPasswordConfirmation = $('#new-password-confirm').val()

    changePassword currentPassword, newPassword, newPasswordConfirmation, (error) ->
      if error
        SettingsSession.errorMessage 'settingsPassword', error.reason or "Unknown error"
      else
        SettingsSession.infoMessage 'settingsPassword', "Password changed sucessfully"
        $('#current-password').val('')
        $('#new-password').val('')
        $('#new-password-confirm').val('')

    return # Make sure CoffeeScript does not return anything

Template.settingsPassword.messages = ->
  SettingsSession.get 'settingsPassword'

changePassword = (currentPassword, newPassword, newPasswordConfirmation, callback) ->
  try
    throw new Meteor.Error 400, "Passwords do not match." if newPassword isnt newPasswordConfirmation
    User.validatePassword newPassword
    Accounts.changePassword currentPassword, newPassword, callback
  catch error
    callback error

