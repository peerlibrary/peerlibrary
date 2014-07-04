Template.settings.person = ->
  return Meteor.person()

Template.settingsUsername.user = ->
  return Meteor.user()

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
  
    # Update password  
    Accounts.changePassword currentPass, newPass, (error) ->
      console.log error
      Notify.meteorError error, true if error
      Notify.success "Password changed sucessfully" unless error

    return # make sure CoffeeScript does not return anything

Template.settingsUsername.events =
  'click button.change-username': (event, template) ->
    event.preventDefault()
    newUsername = $('#new-username').val()
    Meteor.call 'set-username', newUsername, (error, result) ->
      Notify.meteorError error, true if error
      Notify.success "Username changed successfully" unless error
