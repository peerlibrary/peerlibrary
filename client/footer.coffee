Template.baseFooter.searchActive = ->
  Session.get 'searchActive'

Template.footer.indexFooter = ->
  'index-footer' if Session.get('indexActive') and not Session.get('searchActive')

Template.footer.noIndexFooter = ->
  'no-index-footer' if not Template.footer.indexFooter()

Template.footer.events
  'click .newsletter': (e, template) ->
    # Return if not a normal click (maybe user wants to open a link in a tab)
    return if e.altKey or e.ctrlKey or e.metaKey or e.shiftKey
    return unless e.which is 1 # Left mouse button

    e.preventDefault()
    Session.set 'newsletterActive', true
    Session.set 'newsletterError', null
    $(template.findAll '#newsletter-dialog-email').val(Meteor.user()?.emails?[0]?.address or '')

    Meteor.defer =>
      $(template.findAll '#newsletter-dialog-email').focus()

    return # Make sure CoffeeScript does not return anything

  'click .newsletter, focus .newsletter, keypress .newsletter': (e, template) ->
    e.newsletterDialogBoxEvent = true
    return # Make sure CoffeeScript does not return anything

Template.newsletter.newsletterActive = ->
  'newsletter-active' if Session.get 'newsletterActive'

Template.newsletter.newsletterSubscribing = ->
  'newsletter-subscribing' if Session.get 'newsletterSubscribing'

Template.newsletter.newsletterError = ->
  Session.get 'newsletterError'

# To close newsletter dialog box when clicking, focusing, or pressing a key somewhere outside
$(document).on 'click focus keypress', (e) ->
  # originalEvent is defined only for native events, but we are triggering
  # click manually as well, so originalEvent is not always defined
  Session.set 'newsletterActive', false unless e.originalEvent?.newsletterDialogBoxEvent
  return # Make sure CoffeeScript does not return anything

subscribe = (template, email) ->
  return if Session.get 'newsletterSubscribing'
  Session.set 'newsletterSubscribing', true

  Meteor.call 'newsletter-subscribe', email, (error) =>
    Session.set 'newsletterSubscribing', false

    if error
      Session.set 'newsletterError', (error.reason or "Unknown error.")

      # Refocus for user to correct an error
      Meteor.setTimeout =>
        $(template.findAll '#newsletter-dialog-email').focus()
      ,
        10

    else
      Session.set 'newsletterError', null
      Session.set 'newsletterActive', false

      Notify.success "Subscribed to the newsletter.", "To confirm your email address a validation link was sent to you."

# But if clicked inside, we mark the event so that dialog box is not closed
Template.newsletter.events
  # We have to bind directly to newsletter-dialog to intercept click on the parent
  # element of all and not directly on child elements. For example, when input is
  # disabled, its click handler is not called, but newsletter-dialog handler is.
  'click .newsletter-dialog, focus .newsletter-dialog, keypress .newsletter-dialog': (e, template) ->
    e.newsletterDialogBoxEvent = true
    return # Make sure CoffeeScript does not return anything

  'click .subscribe-form-submit': (e, template) ->
    subscribe template, $(template.findAll '#newsletter-dialog-email').val()

    return # Make sure CoffeeScript does not return anything

  'keypress #newsletter-dialog-email': (e, template) ->
    return unless e.keyCode is 13 # Enter key

    subscribe template, $(template.findAll '#newsletter-dialog-email').val()

    return # Make sure CoffeeScript does not return anything
