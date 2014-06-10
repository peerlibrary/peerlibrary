# Common dialog code
# ==================

DIALOG_VARIABLES =
  NEWSLETTER: 'newsletterDialogActive'
  INVITE: 'inviteDialogActive'

# To close newsletter dialog box when clicking, focusing, or pressing a key somewhere outside
$(document).on 'click focus keypress', (e) ->
  # originalEvent is defined only for native events, but we are triggering
  # click manually as well, so originalEvent is not always defined
  for key, variable of DIALOG_VARIABLES
    Session.set variable, false unless variable is e.originalEvent?.preserveDialogVariable

  return # Make sure CoffeeScript does not return anything

# Close all dialogs with escape key
$(document).on 'keyup', (e) ->
  if e.keyCode is 27
    Session.set variable, false for key, variable of DIALOG_VARIABLES

  return # Make sure CoffeeScript does not return anything

# Newsletter subscribe dialog
# ===========================

Template.footer.events
  'click .newsletter': (e, template) ->
    # Return if not a normal click (maybe user wants to open a link in a tab)
    return if e.altKey or e.ctrlKey or e.metaKey or e.shiftKey
    return unless e.which is 1 # Left mouse button

    e.preventDefault()
    Session.set 'newsletterDialogActive', true
    Session.set 'newsletterDialogError', null

    # Prefill subscribe form with user's email
    $email = $(template.findAll '#newsletter-dialog-email')
    $email.val Meteor.person(Person.emailFields())?.email() unless $email.val()

    Meteor.setTimeout =>
      $(template.findAll '#newsletter-dialog-email').focus()
    , 10 # ms

    return # Make sure CoffeeScript does not return anything

  'click .newsletter, focus .newsletter, keypress .newsletter': (e, template) ->
    e.preserveDialogVariable = DIALOG_VARIABLES.NEWSLETTER
    return # Make sure CoffeeScript does not return anything

Template.newsletterDialog.displayed = ->
  Session.get 'newsletterDialogActive'

Template.newsletterDialog.waiting = ->
  Session.get 'newsletterDialogSubscribing'

Template.newsletterDialog.error = ->
  Session.get 'newsletterDialogError'

# But if clicked inside, we mark the event so that dialog box is not closed
Template.newsletterDialog.events
# We have to bind directly to newsletter-dialog to intercept click on the parent
# element of all and not directly on child elements. For example, when input is
# disabled, its click handler is not called, but newsletter-dialog handler is.
  'click .newsletter-dialog, focus .newsletter-dialog, keypress .newsletter-dialog': (e, template) ->
    e.preserveDialogVariable = DIALOG_VARIABLES.NEWSLETTER
    return # Make sure CoffeeScript does not return anything

  'submit .newsletter-subscribe': (e, template) ->
    e.preventDefault()
    return if Session.get 'newsletterDialogSubscribing'

    email = $(template.findAll '#newsletter-dialog-email').val()

    unless email.match EMAIL_REGEX
      Session.set 'newsletterDialogError', "Please enter a valid email address."
      return

    Session.set 'newsletterDialogSubscribing', true

    Meteor.call 'newsletter-subscribe', email, (error) =>
      Session.set 'newsletterDialogSubscribing', false

      if error
        Session.set 'newsletterDialogError', (error.reason or "Unknown error.")

        # Refocus for user to correct an error
        Meteor.setTimeout =>
          $(template.findAll '#newsletter-dialog-email').focus()
        , 10 # ms

      else
        Session.set 'newsletterDialogError', null
        Session.set 'newsletterDialogActive', false
        $(template.findAll '#newsletter-dialog-email').val('')

        Notify.success "Subscribed to the newsletter.", "To confirm your email address a validation link was sent to you."

    return # Make sure CoffeeScript does not return anything

# Invite dialog
# =============

Template._loginButtonsLoggedInDropdownActions.events
  'click .invite-button': (e, template) ->
    Session.set 'inviteDialogActive', true
    Session.set 'inviteDialogError', null

    Accounts._loginButtonsSession.closeDropdown()

    Meteor.setTimeout =>
      $('#invite-dialog-email').focus()
    , 10 # ms

    return # Make sure CoffeeScript does not return anything

  'click .invite-button, focus .invite-button, keypress .invite-button': (e, template) ->
    e.preserveDialogVariable = DIALOG_VARIABLES.INVITE
    return # Make sure CoffeeScript does not return anything

Template.inviteDialog.displayed = ->
  Session.get 'inviteDialogActive'

Template.inviteDialog.waiting = ->
  Session.get 'inviteDialogSending'

Template.inviteDialog.error = ->
  Session.get 'inviteDialogError'

# But if clicked inside, we mark the event so that dialog box is not closed
Template.inviteDialog.events
# We have to bind directly to invite-dialog to intercept click on the parent
# element of all and not directly on child elements. For example, when input is
# disabled, its click handler is not called, but invite-dialog handler is.
  'click .invite-dialog, focus .invite-dialog, keypress .invite-dialog': (e, template) ->
    e.preserveDialogVariable = DIALOG_VARIABLES.INVITE
    return # Make sure CoffeeScript does not return anything

  'submit .invite-send': (e, template) ->
    e.preventDefault()
    return if Session.get 'inviteDialogSending'

    email = $(template.findAll '#invite-dialog-email').val().trim()

    unless email.match EMAIL_REGEX
      Session.set 'inviteDialogError', "Please enter a valid email address."
      return

    message = $(template.findAll '#invite-dialog-message').val().trim()

    Session.set 'inviteDialogSending', true

    inviteUser email, message
    ,
      (newPersonId) =>
        Session.set 'inviteDialogSending', false
        Session.set 'inviteDialogError', null
        Session.set 'inviteDialogActive', false

        # We are clearing the email and not the optional message (so it can be reused)
        $('#invite-dialog-email').val('')

        return true # Show success notification
    ,
      (error) =>
        Session.set 'inviteDialogSending', false
        Session.set 'inviteDialogError', (error.reason or "Unknown error.")

        # Refocus for user to correct an error
        Meteor.setTimeout =>
          $(template.findAll '#invite-dialog-email').focus()
        , 10 # ms

        return false # We've handled the error ourselves, so don't show the notification

    return # Make sure CoffeeScript does not return anything