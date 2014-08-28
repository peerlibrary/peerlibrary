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

  # Helper object with properties useful to refer to this document. Optional group document.
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
    groupHandle = Meteor.subscribe 'groups-by-ids', Session.get 'currentGroupId'
    Meteor.subscribe 'my-join-requests', Session.get 'currentGroupId'
    Meteor.subscribe 'my-leave-requests', Session.get 'currentGroupId'
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
  Group.documents.findOne Session.get('currentGroupId'), fields: searchResult: 0

Editable.template Template.groupName, ->
  @data.hasMaintainerAccess Meteor.person @data.constructor.maintainerAccessPersonFields()
,
(name) ->
  Meteor.call 'group-set-name', @data._id, name, (error, count) ->
    return FlashMessage.fromError error, true if error
,
  "Enter group name"
,
  true

Template.groupMembership.isMember = ->
  person = Meteor.person()
  return false unless person?.inGroups
  _.some person.inGroups, (group) -> group._id is Session.get 'currentGroupId'

Template.groupMembership.isPendingMember = ->
  person = Meteor.person()
  group = Group.documents.findOne(_id: Session.get 'currentGroupId')
  return false unless person and group
  _.some group.joinRequests, (person) -> person._id is Meteor.personId()

Template.groupNoMembership.open = ->
  Group.documents.findOne(_id: Session.get 'currentGroupId').joinPolicy is Group.POLICY.OPEN

Template.groupNoMembership.closed = ->
  Group.documents.findOne(_id: Session.get 'currentGroupId').joinPolicy is Group.POLICY.CLOSED

Template.groupMembership.events
  'click .join-group': (event, template) ->
    console.log "Join group clicked"
    Meteor.call 'request-to-join-group', Session.get('currentGroupId'), (error) =>
      return FlashMessage.fromError error, true if error

    return # Make sure CoffeeScript does not return anything

  'click .leave-group': (event, template) ->
    console.log "Leave group clicked"
    Meteor.call 'request-to-leave-group', Session.get('currentGroupId'), (error) =>
      return FlashMessage.fromError error, true if error

    return # Make sure CoffeeScript does not return anything

  'click .cancel-request-to-join-group': (event, template) ->
    console.log "Cancel request clicked"
    Meteor.call 'cancel-request-to-join-group', Session.get('currentGroupId'), (error) =>
      return FlashMessage.fromError error, true if error

    return # Make sure CoffeeScript does not return anything

Template.groupMembersList.created = ->
  @_personsInvitedHandle = Meteor.subscribe 'persons-invited'

Template.groupMembersList.destroyed = ->
  @_personsInvitedHandle?.stop()
  @_personsInvitedHandle = null

Template.groupMembersList.membersWithFlag = ->
  hasAdminAccess = @hasAdminAccess Meteor.person @constructor.adminAccessPersonFields()
  canModifySelf = @leavePolicy isnt Group.POLICY.CLOSED
  _.map @members, (member) ->
    showFlag = if member._id is Meteor.personId() then canModifySelf or hasAdminAccess else hasAdminAccess
    member.readOnly = not showFlag
    member
  #@members

Template.groupMembersList.events
  'click .remove-button': (event, template) ->
    currentGroupId = Session.get('currentGroupId')
    if @hasAdminAccess Meteor.person @constructor.adminAccessPersonFields()
      Meteor.call 'remove-from-group', currentGroupId, @_id, (error, count) =>
        return FlashMessage.fromError error, true if error
    else
      Meteor.call 'request-to-leave-group', currentGroupId, (error, count) =>
        return FlashMessage.fromError error, true if error

    return # Make sure CoffeeScript does not return anything

Template.groupRequests.canModifyMembership = ->
  @hasAdminAccess Meteor.person @constructor.adminAccessPersonFields()

Template.groupRequests.events =
  'click .join-requests .approve-button': (event, template) ->
    Meteor.call 'add-to-group', Session.get('currentGroupId'), @_id, (error, count) =>
      return FlashMessage.fromError error, true if error

    return # Make sure CoffeeScript does not return anything

  'click .join-requests .remove-button': (event, template) ->
    Meteor.call 'deny-request-to-join-group', Session.get('currentGroupId'), @_id, (error, count) =>
      return FlashMessage.fromError error, true if error

    return # Make sure CoffeeScript does not return anything

  'click .leave-requests .approve-button': (event, template) ->
    Meteor.call 'remove-from-group', Session.get('currentGroupId'), @_id, (error, count) =>
      return FlashMessage.fromError error, true if error

    return # Make sure CoffeeScript does not return anything

  'click .leave-requests .remove-button': (event, template) ->
    Meteor.call 'deny-request-to-leave-group', Session.get('currentGroupId'), @_id, (error, count) =>
      return FlashMessage.fromError error, true if error

    return # Make sure CoffeeScript does not return anything

Template.groupMembersAddControl.canModifyMembership = ->
  @hasAdminAccess Meteor.person @constructor.adminAccessPersonFields()

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

Template.groupMembersAddControlNoResults.email = Template.rolesControlNoResults.email

addMemberToGroup = (personId) ->
  Meteor.call 'add-to-group', Session.get('currentGroupId'), personId, (error, count) =>
    return FlashMessage.fromError error, true if error

    FlashMessage.success "Member added." if count

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

Template.groupSettings.canRemove = ->
  @hasRemoveAccess Meteor.person @constructor.removeAccessPersonFields()

Template.groupAdminTools.POLICY = ->
  Group.POLICY

Template.groupAdminTools.isCurrentJoinPolicy = (policy) ->
  group = Group.documents.findOne(_id: Session.get 'currentGroupId')
  return false unless group
  group.joinPolicy is policy

Template.groupAdminTools.isCurrentLeavePolicy = (policy) ->
  group = Group.documents.findOne(_id: Session.get 'currentGroupId')
  return false unless group
  group.leavePolicy is policy

Template.groupAdminTools.canModify = ->
  @hasMaintainerAccess Meteor.person @constructor.maintainerAccessPersonFields()

Template.groupAdminTools.events
  'click .dropdown-trigger': (event, template) ->
    # Make sure only the trigger toggles the dropdown, by
    # excluding clicks inside the content of this dropdown
    return if $.contains template.find('.dropdown-anchor'), event.target

    $(template.findAll '.dropdown-anchor').toggle()

    return # Make sure CoffeeScript does not return anything

  'click .delete-group': (event, template) ->
    Meteor.call 'remove-group', @_id, (error, count) =>
      FlashMessage.fromError error, true if error

      return unless count

      FlashMessage.success "Group removed."
      Meteor.Router.toNew Meteor.Router.groupsPath()

    return # Make sure CoffeeScript does not return anything

  'change .group-join-policy': (event, template) ->
    policy = parseInt $('.group-join-policy').val()
    console.log "New join policy: " + policy
    Meteor.call 'group-set-join-policy', @_id, policy, (error, count) =>
      FlashMessage.fromError error, true if error

    return # Make sure CoffeeScript does not return anything

  'change .group-leave-policy': (event, template) ->
    policy = parseInt $('.group-leave-policy').val()
    console.log "New leave policy: " + policy
    Meteor.call 'group-set-leave-policy', @_id, policy, (error, count) =>
      FlashMessage.fromError error, true if error

    return # Make sure CoffeeScript does not return anything

Template.groupMembersAddControlInviteHint.visible = ->
  addGroupMembersReactiveVariables @

  !@_query()

Handlebars.registerHelper 'groupPathFromId', _.bind Group.pathFromId, Group

Handlebars.registerHelper 'groupReference', _.bind Group.reference, Group
