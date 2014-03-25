Deps.autorun ->
  if Session.equals 'groupsActive', true
    Meteor.subscribe 'groups'

Template.groups.searchActive = ->
  !!Session.get 'groupsSearchQuery'

Template.groups.groups = ->
  searchTerm = Session.get 'groupsSearchQuery'

  selector = {}

  if !!searchTerm
    selector =
      name:
        $regex : ".*#{searchTerm}.*"
        $options : "i"

  Group.documents.find selector,
    sort:
      membersCount: -1
      name: 1


Template.groups.events
  'keyup .groups-directory .search-input': (e, template) ->
    val = $(template.findAll '.groups-directory .search-input').val()

    Session.set 'groupsSearchQuery', val

    return # Make sure CoffeeScript does not return anything

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

Template.groupListing.countDescription = ->
  if @membersCount is 1 then "1 member" else "#{@membersCount} members"

Template.myGroups.myGroups = ->
  Group.documents.find
    _id:
      $in: _.pluck Meteor.person()?.inGroups, '_id'
  ,
    sort:
      name: 1