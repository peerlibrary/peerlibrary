Template.install.helpers
  created: Template.indexMain.helpers 'created'

  rendered: Template.indexMain.helpers 'rendered'

  destroyed: Template.indexMain.helpers 'destroyed'

Template.installWizard.helpers
  installError: ->
    Session.get 'installError'

Template.installWizard.helpers
  installInProgress: ->
    'install-in-progress' if Session.get 'installInProgress'

Template.installWizard.helpers
  installRestarting: ->
    Session.get 'installRestarting'

Template.installWizard.rendered = ->
  Meteor.setTimeout =>
    @$('#install-password-input').focus()
  , 10 # ms

Template.installWizard.events
  'submit form.password': (event, template) ->
    event.preventDefault()

    return if Session.get 'installInProgress'
    Session.set 'installInProgress', true

    Meteor.call 'create-admin-account', template.$('#install-password-input').val(), (error) ->
      if error
        Session.set 'installInProgress', false
        Session.set 'installError', (error.reason or "Unknown error.")

        # Refocus for user to correct an error
        Meteor.setTimeout =>
          template.$('#install-password-input').focus()
        , 10 # ms
      else
        # We keep installInProgress set to true to prevent any race-condition duplicate form submission

        # Server side will reload the client
        Session.set 'installRestarting', true
