Deps.autorun ->
  if Session.equals 'groupsActive', true
    Meteor.subscribe 'groups'

groupSearchQuery = null
groupSearchQueryDependency = new Deps.Dependency()

Template.groups.searchQuery = ->
  groupSearchQuery

Template.groups.groups = ->
  groupSearchQueryDependency.depend()

  selector = {}

  # TODO: Move filtering of the groups to server, escape query
  if groupSearchQuery
    selector =
      name:
        $regex: ".*#{groupSearchQuery}.*"
        $options: "i"

  Group.documents.find selector,
    sort: [
      ['membersCount', 'desc']
      ['name', 'asc']
    ]

Template.groups.events
  'keyup .groups-directory .search-input': (e, template) ->
    val = $(template.findAll '.groups-directory .search-input').val()

    groupSearchQuery = val
    groupSearchQueryDependency.changed()

    return # Make sure CoffeeScript does not return anything

  'submit .add-group': (e, template) ->
    e.preventDefault()

    name = $(template.findAll '.name').val().trim()
    return unless name

    Meteor.call 'create-group', name, (error, groupId) =>
      return Notify.meteorError error, true if error

      Notify.success "Group created."

    return # Make sure CoffeeScript does not return anything

Template.groupListing.countDescription = ->
  if @membersCount is 1 then "1 member" else "#{ @membersCount } members"

Template.myGroups.myGroups = ->
  Group.documents.find
    _id:
      $in: _.pluck Meteor.person()?.inGroups, '_id'
  ,
    sort: [
      ['name', 'asc']
    ]
