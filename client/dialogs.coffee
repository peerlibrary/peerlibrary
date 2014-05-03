# Common dialog code
# ==================

# To close newsletter dialog box when clicking, focusing, or pressing a key somewhere outside
$(document).on 'click focus keypress', (e) ->
  # originalEvent is defined only for native events, but we are triggering
  # click manually as well, so originalEvent is not always defined
  (Session.set variable, false for variable in ['newsletterActive', 'inviteDialogActive']) unless e.originalEvent?.dialogBoxEvent

  return # Make sure CoffeeScript does not return anything

# Newsletter subsribe dialog
# ==========================

Template.footer.events
  'click .newsletter': (e, template) ->
    # Return if not a normal click (maybe user wants to open a link in a tab)
    return if e.altKey or e.ctrlKey or e.metaKey or e.shiftKey
    return unless e.which is 1 # Left mouse button

    e.preventDefault()
    Session.set 'newsletterActive', true
    Session.set 'newsletterError', null
    $(template.findAll '#newsletter-dialog-email').val(Meteor.person()?.email() or '')

    Meteor.setTimeout =>
      $(template.findAll '#newsletter-dialog-email').focus()
    , 10 # ms

    return # Make sure CoffeeScript does not return anything

  'click .newsletter, focus .newsletter, keypress .newsletter': (e, template) ->
    e.dialogBoxEvent = true
    return # Make sure CoffeeScript does not return anything

Template.newsletter.displayed = ->
  Session.get 'newsletterActive'

Template.newsletter.waiting = ->
  Session.get 'newsletterSubscribing'

Template.newsletter.newsletterError = ->
  Session.get 'newsletterError'

$(document).on 'keyup', (e) ->
  Session.set 'newsletterActive', false if e.keyCode is 27 # Escape key
  return # Make sure CoffeeScript does not return anything

# But if clicked inside, we mark the event so that dialog box is not closed
Template.newsletter.events
# We have to bind directly to newsletter-dialog to intercept click on the parent
# element of all and not directly on child elements. For example, when input is
# disabled, its click handler is not called, but newsletter-dialog handler is.
  'click .newsletter-dialog, focus .newsletter-dialog, keypress .newsletter-dialog': (e, template) ->
    e.dialogBoxEvent = true
    return # Make sure CoffeeScript does not return anything

  'submit .newsletter-subscribe': (e, template) ->
    e.preventDefault()
    return if Session.get 'newsletterSubscribing'

    email = $(template.findAll '#newsletter-dialog-email').val()

    unless email.match EMAIL_REGEX
      Session.set 'newsletterError', "Please enter a valid email address."
      return

    Session.set 'newsletterSubscribing', true

    Meteor.call 'newsletter-subscribe', email, (error) =>
      Session.set 'newsletterSubscribing', false

      if error
        Session.set 'newsletterError', (error.reason or "Unknown error.")

        # Refocus for user to correct an error
        Meteor.setTimeout =>
          $(template.findAll '#newsletter-dialog-email').focus()
        , 10 # ms

      else
        Session.set 'newsletterError', null
        Session.set 'newsletterActive', false

        Notify.success "Subscribed to the newsletter.", "To confirm your email address a validation link was sent to you."

    return # Make sure CoffeeScript does not return anything

# Invite dialog
# =============

Template._loginButtonsLoggedInDropdownActions.events
  'click .invite-button': (e, template) ->
    Session.set 'inviteDialogActive', true
    Session.set 'inviteDialogError', null
    $('#invite-dialog-email').val('')

    Accounts._loginButtonsSession.closeDropdown()

    Meteor.setTimeout =>
      $('#invite-dialog-email').focus()
    , 10 # ms

    return # Make sure CoffeeScript does not return anything

  'click .invite-button, focus .invite-button, keypress .invite-button': (e, template) ->
    e.dialogBoxEvent = true
    return # Make sure CoffeeScript does not return anything

Template.inviteDialog.displayed = ->
  Session.get 'inviteDialogActive'

Template.inviteDialog.waiting = ->
  Session.get 'inviteDialogSending'

Template.inviteDialog.inviteError = ->
  Session.get 'inviteDialogError'

$(document).on 'keyup', (e) ->
  Session.set 'inviteDialogActive', false if e.keyCode is 27 # Escape key
  return # Make sure CoffeeScript does not return anything

# But if clicked inside, we mark the event so that dialog box is not closed
Template.inviteDialog.events
# We have to bind directly to invite-dialog to intercept click on the parent
# element of all and not directly on child elements. For example, when input is
# disabled, its click handler is not called, but invite-dialog handler is.
  'click .invite-dialog, focus .invite-dialog, keypress .invite-dialog': (e, template) ->
    e.dialogBoxEvent = true
    return # Make sure CoffeeScript does not return anything

  'submit .invite-send': (e, template) ->
    e.preventDefault()
    return if Session.get 'inviteDialogSending'

    email = $(template.findAll '#invite-dialog-email').val()

    unless email.match EMAIL_REGEX
      Session.set 'inviteDialogError', "Please enter a valid email address."
      return

    Session.set 'inviteDialogSending', true

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

