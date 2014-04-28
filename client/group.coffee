groupHandle = null

# Mostly used just to force reevaluation of groupHandle
groupSubscribing = new Variable false

Deps.autorun ->
  if Session.get 'currentGroupId'
    groupSubscribing.set true
    groupHandle = Meteor.subscribe 'groups-by-id', Session.get 'currentGroupId'
  else
    groupSubscribing.set false
    groupHandle = null

Deps.autorun ->
  if groupSubscribing() and groupHandle?.ready()
    groupSubscribing.set false

Deps.autorun ->
  group = Group.documents.findOne Session.get('currentGroupId'),
    fields:
      _id: 1
      slug: 1

  return unless group

  # currentGroupSlug is null if slug is not present in location, so we use
  # null when group.slug is empty string to prevent infinite looping
  return if Session.equals 'currentGroupSlug', (group.slug or null)

  Meteor.Router.toNew Meteor.Router.groupPath group._id, group.slug

Template.group.loading = ->
  groupSubscribing() # To register dependency
  not groupHandle?.ready()

Template.group.notfound = ->
  groupSubscribing() # To register dependency
  groupHandle?.ready() and not Group.documents.findOne Session.get('currentGroupId'), fields: _id: 1

Template.group.group = ->
  Group.documents.findOne Session.get 'currentGroupId'

Template.group.canModifyMembership = ->
  Group.documents.findOne(Session.get('currentGroupId'))?.hasAdminAccess Meteor.person()

Editable.template Template.groupName, ->
  @data.hasMaintainerAccess Meteor.person()
,
  (name) ->
    Meteor.call 'group-set-name', @data._id, name, (error, count) ->
      return Notify.meteorError error, true if error
,
  "Enter group name"
,
  true

Template.groupMembersAddControl.events
  'change .add-group-member, keyup .add-group-member': (e, template) ->
    e.preventDefault()

    # TODO: Misusing data context for a variable, add to the template instance instead: https://github.com/meteor/meteor/issues/1529
    @_query.set $(template.findAll '.add-group-member').val()

    return # Make sure CoffeeScript does not return anything

# TODO: Misusing data context for a variable, use template instance instead: https://github.com/meteor/meteor/issues/1529
addGroupMembersReactiveVariables = (data) ->
  if data._query
    assert data._loading
    return

  data._query = new Variable ''
  data._loading = new Variable 0

  data._newDataContext = true

Template.groupMembersAddControl.created = ->
  @_searchHandle = null

  addGroupMembersReactiveVariables @data

Template.groupMembersAddControl.rendered = ->
  addGroupMembersReactiveVariables @data

  if @_searchHandle and @data._newDataContext
    @_searchHandle.stop()
    @_searchHandle = null

  delete @data._newDataContext

  return if @_searchHandle
  @_searchHandle = Deps.autorun =>
    if @data._query()
      loading = true
      @data._loading.set Deps.nonreactive(@data._loading) + 1
      Meteor.subscribe 'search-persons', @data._query(), _.pluck(@data.members, '_id'),
        onReady: =>
          @data._loading.set Deps.nonreactive(@data._loading) - 1 if loading
          loading = false
        onError: =>
          # TODO: Should we display some error?
          @data._loading.set Deps.nonreactive(@data._loading) - 1 if loading
          loading = false
      Deps.onInvalidate =>
        @data._loading.set Deps.nonreactive(@data._loading) - 1 if loading
        loading = false

Template.groupMembersAddControl.destroyed = ->
  @_searchHandle.stop() if @_searchHandle
  @_searchHandle = null

  @data._query = null
  @data._loading = null

  delete @data._newDataContext

Template.groupMembersAddControlNoResults.noResults = ->
  addGroupMembersReactiveVariables @

  query = @_query()

  return unless query

  searchResult = SearchResult.documents.findOne
    name: 'search-persons'
    query: query

  return unless searchResult

  not @_loading() and not (searchResult.countPersons or 0)

Template.groupMembersAddControlLoading.loading = ->
  addGroupMembersReactiveVariables @

  @_loading()

Template.groupMembersAddControlResults.results = ->
  addGroupMembersReactiveVariables @

  query = @_query()

  return unless query

  searchResult = SearchResult.documents.findOne
    name: 'search-persons'
    query: query

  return unless searchResult

  personsLimit = Math.min searchResult.countPersons, 5

  return unless personsLimit

  Person.documents.find
    'searchResult._id': searchResult._id
  ,
    sort: [
      ['searchResult.order', 'asc']
    ]
    limit: personsLimit

Template.groupMembersList.events
  'click .remove-button': (e, template) ->

    Meteor.call 'remove-from-group', Session.get('currentGroupId'), @_id, (error, count) =>
      return Notify.meteorError error, true if error

      Notify.success "Member removed." if count

    return # Make sure CoffeeScript does not return anything

Template.groupMembersList.canModifyMembership = Template.group.canModifyMembership

Template.groupMembersAddControlResultsItem.events
  'click .add-button': (e, template) ->

    return unless @_id

    return if @_id in _.pluck Group.documents.findOne(Session.get('currentGroupId')).members, '_id'

    Meteor.call 'add-to-group', Session.get('currentGroupId'), @_id, (error, count) =>
      return Notify.meteorError error, true if error

      Notify.success "Member added." if count

    return # Make sure CoffeeScript does not return anything

# We allow passing the group slug if caller knows it
Handlebars.registerHelper 'groupPathFromId', (groupId, slug, options) ->
  group = Group.documents.findOne groupId

  return Meteor.Router.groupPath group._id, group.slug if group

  Meteor.Router.groupPath groupId, slug

# Optional group document
Handlebars.registerHelper 'groupReference', (groupId, group, options) ->
  group = Group.documents.findOne groupId unless group
  assert groupId, group._id if group

  _id: groupId # TODO: Remove when we will be able to access parent template context
  text: "g:#{ groupId }"
  title: group?.name or group?.slug
