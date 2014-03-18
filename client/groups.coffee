Template.groups.events
  'submit .add-group': (e, template) ->
    e.preventDefault()

    Group.documents.insert
      name: $(template.findAll '.name').val()
      members: [
        _id: Meteor.personId()
      ]
    ,
      (error, id) =>
        return Notify.meteorError error, true if error

        Notify.success "Group created."
        Meteor.Router.toNew Meteor.Router.groupPath id

    return # Make sure CoffeeScript does not return anything
