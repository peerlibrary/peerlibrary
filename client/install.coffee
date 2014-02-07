Template.install.events
  'submit form.password': (e, template) ->
    e.preventDefault()

    Meteor.call 'create-admin-account', $(template.findAll 'input.password').val(), (error) ->
      Notify.meteorError error if error

      # Server side will reload the client

Template.install.created = Template.indexMain.created

Template.install.rendered = Template.indexMain.rendered

Template.install.destroyed = Template.indexMain.destroyed
