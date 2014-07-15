Template.settings.person = ->
  return Meteor.person()

Template.settingsUsername.user = ->
  return Meteor.user()

Handlebars.registerHelper "usernameNotSet", ->
  return !Meteor.person().user.username

Template.settingsPassword.events =
  'click button.change-password': (event, template) ->
    event.preventDefault()
    currentPass = $('#current-password').val()
    newPass = $('#new-password').val()
    newPassConfirm = $('#new-password-confirm').val()

    # Check if new password is confirmed
    if newPass != newPassConfirm
      error = new Meteor.Error 400, "Passwords do not match"
      Notify.meteorError error, true
      return # make sure CoffeeScript does not return anything

    # TODO: This should probably be checked at one central place
    if newPass.length < 6
      Notify.meteorError new Meteor.Error 400, "Password must be at least 6 characters long"
      return # make sure CoffeeScript does not return anything

    # Update password
    Accounts.changePassword currentPass, newPass, (error) ->
      if error
        Notify.meteorError error, true
      else
        Notify.success "Password changed sucessfully"
        $('#current-password').val('')
        $('#new-password').val('')
        $('#new-password-confirm').val('')

    return # make sure CoffeeScript does not return anything

Template.settingsUsername.events =
  'click button.set-username': (event, template) ->
    event.preventDefault()
    username = $('#username').val()
    Meteor.call 'set-username', username, (error) ->
      Notify.meteorError error, true if error
      Notify.success "Username set successfully" unless error

    return # make sure CoffeeScript does not return anything

