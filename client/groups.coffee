Catalog.create 'groups', Group,
  main: Template.groups
  count: Template.groupsCount
  empty: Template.noGroups
  loading: Template.groupsLoading
,
  active: 'groupsActive'
  ready: 'currentGroupsReady'
  loading: 'currentGroupsLoading'
  count: 'currentGroupsCount'
  filter: 'currentGroupsFilter'
  limit: 'currentGroupsLimit'
  sort: 'currentGroupsSort'

Deps.autorun ->
  if Session.equals 'groupsActive', true
    Meteor.subscribe 'my-groups'

Template.groups.catalogSettings = ->
  settings =
    collection: "groups"
    sorting: [
        name: 'members'
        sort: [
          ['membersCount', 'desc']
          ['name', 'asc']
        ]
      ,
        name: 'name'
        sort: [
          ['name', 'asc']
        ]
      ,
        name: 'last active'
        sort: [
          ['updatedAt', 'desc']
          ['membersCount', 'desc']
          ['name', 'asc']
        ]
    ]
    variables:
      filter: 'currentGroupsFilter'
      sort: 'currentGroupsSort'
      sortName: 'currentGroupsSortName'

  settings

Template.groups.events
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
