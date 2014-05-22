Catalog.create 'groups', Group,
  main: Template.groups
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
  documentClass: Group
  variables:
    filter: 'currentGroupsFilter'
    sort: 'currentGroupsSort'

Template.groups.events
  'submit .add-group': (e, template) ->
    e.preventDefault()

    name = $(template.findAll '.name').val().trim()
    return unless name

    Meteor.call 'create-group', name, (error, groupId) =>
      return Notify.meteorError error, true if error

      Notify.success "Group created."

    return # Make sure CoffeeScript does not return anything

Template.myGroups.myGroups = ->
  Group.documents.find
    _id:
      $in: _.pluck Meteor.person()?.inGroups, '_id'
  ,
    sort: [
      ['name', 'asc']
    ]
