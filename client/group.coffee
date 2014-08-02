class @Group extends Group
  @Meta
    name: 'Group'
    replaceParent: true

  # We allow passing the group slug if caller knows it
  @pathFromId: (groupId, slug, options) ->
    assert _.isString groupId
    # To allow calling template helper with only one argument (group will be options then)
    group = null unless _.isString group

    group = @documents.findOne groupId

    return Meteor.Router.groupPath group._id, (group.slug ? slug) if group

    Meteor.Router.groupPath groupId, slug

  path: ->
    @constructor.pathFromId @_id, @slug

  # Helper object with properties useful to refer to this document
  # Optional group document
  @reference: (groupId, group, options) ->
    assert _.isString groupId
    # To allow calling template helper with only one argument (collection will be options then)
    group = null unless group instanceof @

    group = @documents.findOne groupId unless group
    assert groupId, group._id if group

    _id: groupId # TODO: Remove when we will be able to access parent template context
    text: "g:#{ groupId }"
    title: group?.name or group?.slug

  reference: ->
    @constructor.reference @_id, @

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

Template.group.notFound = ->
  groupSubscribing() # To register dependency
  groupHandle?.ready() and not Group.documents.findOne Session.get('currentGroupId'), fields: _id: 1

Template.group.group = ->
  Group.documents.findOne Session.get 'currentGroupId'

Editable.template Template.groupName, ->
  @data.hasMaintainerAccess Meteor.person @data.constructor.maintainerAccessPersonFields()
,
(name) ->
  Meteor.call 'group-set-name', @data._id, name, (error, count) ->
    return Notify.meteorError error, true if error
,
  "Enter group name"
,
  true

Template.groupMembers.canModifyMembership = ->
  @hasAdminAccess Meteor.person @constructor.adminAccessPersonFields()

Template.groupMembersList.created = ->
  @_personsInvitedHandle = Meteor.subscribe 'persons-invited'

Template.groupMembersList.destroyed = ->
  @_personsInvitedHandle?.stop()
  @_personsInvitedHandle = null

Template.groupMembersList.canModifyMembership = Template.groupMembers.canModifyMembership

Template.groupMembersList.events
  'click .remove-button': (event, template) ->

    Meteor.call 'remove-from-group', Session.get('currentGroupId'), @_id, (error, count) =>
      return Notify.meteorError error, true if error

      Notify.success "Member removed." if count

    return # Make sure CoffeeScript does not return anything

Template.groupMembersAddControl.events
  'change .add-group-member, keyup .add-group-member': (event, template) ->
    event.preventDefault()

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
  @_searchHandle?.stop()
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

Template.groupMembersAddControlNoResults.email = Template.privateAccessControlNoResults.email

addMemberToGroup = (personId) ->
  Meteor.call 'add-to-group', Session.get('currentGroupId'), personId, (error, count) =>
    return Notify.meteorError error, true if error

    Notify.success "Member added." if count

Template.groupMembersAddControlNoResults.events
  'click .add-and-invite': (event, template) ->

    # We get the email in @ (this), but it's a String object that also has
    # the parent context attached so we first convert it to a normal string.
    email = "#{ @ }"

    return unless email?.match EMAIL_REGEX

    inviteUser email, null, (newPersonId) =>
      addMemberToGroup newPersonId
      return true # Show success notification

    return # Make sure CoffeeScript does not return anything

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

Template.groupMembersAddControlResultsItem.events
  'click .add-button': (event, template) ->

    return unless @_id

    return if @_id in _.pluck Group.documents.findOne(Session.get('currentGroupId')).members, '_id'

    addMemberToGroup @_id

    return # Make sure CoffeeScript does not return anything

Template.groupDetails.canModify = ->
  @hasMaintainerAccess Meteor.person @constructor.maintainerAccessPersonFields()

Template.groupDetails.canRemove = ->
  @hasRemoveAccess Meteor.person @constructor.removeAccessPersonFields()

Template.groupDetails.events
  'click .delete-group': (event, template) ->
    Meteor.call 'remove-group', @_id, (error, count) =>
      Notify.meteorError error, true if error

      return unless count

      Notify.success "Group removed."
      Meteor.Router.toNew Meteor.Router.groupsPath()

    return # Make sure CoffeeScript does not return anything

Handlebars.registerHelper 'groupPathFromId', _.bind Group.pathFromId, Group

Handlebars.registerHelper 'groupReference', _.bind Group.reference, Group
