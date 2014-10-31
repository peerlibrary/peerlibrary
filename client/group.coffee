class @Group extends Group
  @Meta
    name: 'Group'
    replaceParent: true

  # We allow passing the group slug if caller knows it
  @pathFromId: (groupId, slug) ->
    assert _.isString groupId

    group = @documents.findOne groupId

    return Meteor.Router.groupPath group._id, (group.slug ? slug) if group

    Meteor.Router.groupPath groupId, slug

  path: =>
    @constructor.pathFromId @_id, @slug

  route: =>
    source: @constructor.verboseName()
    route: 'group'
    params:
      groupId: @_id
      groupSlug: @slug

  # Helper object with properties useful to refer to this document. Optional group document.
  @reference: (groupId, group) ->
    assert _.isString groupId

    group = @documents.findOne groupId unless group
    assert groupId, group._id if group

    _id: groupId # TODO: Remove when we will be able to access parent template context
    text: "g:#{ groupId }"
    title: group?.name or group?.slug

  reference: =>
    @constructor.reference @_id, @

groupHandle = null

# Mostly used just to force reevaluation of groupHandle
groupSubscribing = new Variable false

Tracker.autorun ->
  if Session.get 'currentGroupId'
    groupSubscribing.set true
    groupHandle = Meteor.subscribe 'groups-by-ids', Session.get 'currentGroupId'
  else
    groupSubscribing.set false
    groupHandle = null

Tracker.autorun ->
  if groupSubscribing() and groupHandle?.ready()
    groupSubscribing.set false

Tracker.autorun ->
  group = Group.documents.findOne Session.get('currentGroupId'),
    fields:
      _id: 1
      slug: 1

  return unless group

  # currentGroupSlug is null if slug is not present in location, so we use
  # null when group.slug is empty string to prevent infinite looping
  return if Session.equals 'currentGroupSlug', (group.slug or null)

  Meteor.Router.toNew Meteor.Router.groupPath group._id, group.slug

Template.group.helpers
  loading: ->
    groupSubscribing() # To register dependency
    not groupHandle?.ready()

  notFound: ->
    groupSubscribing() # To register dependency
    groupHandle?.ready() and not Group.documents.findOne Session.get('currentGroupId'), fields: _id: 1

  group: ->
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

Template.groupMembers.helpers
  canModifyMembership: ->
    return unless @_id
    @hasAdminAccess Meteor.person @constructor.adminAccessPersonFields()

Template.groupMembersList.created = ->
  @_personsInvitedHandle = Meteor.subscribe 'persons-invited'

Template.groupMembersList.destroyed = ->
  @_personsInvitedHandle?.stop()
  @_personsInvitedHandle = null

Template.groupMembersList.helpers
  canModifyMembership: Template.groupMembers.helpers 'canModifyMembership'

Template.groupMembersList.events
  'click .remove-button': (event, template) ->

    Meteor.call 'remove-from-group', Session.get('currentGroupId'), @_id, (error, count) =>
      return FlashMessage.fromError error, true if error

      FlashMessage.success "Member removed." if count

    return # Make sure CoffeeScript does not return anything

Template.groupMembersAddControl.helpers
  canModifyMembership: Template.groupMembersList.helpers 'canModifyMembership'

Template.groupMembersAddControl.events
  'change .add-group-member, keyup .add-group-member': (event, template) ->
    event.preventDefault()

    template._query.set template.$('.add-group-member').val().trim()

    return # Make sure CoffeeScript does not return anything

Template.groupMembersAddControl.created = ->
  @_searchHandle = null
  @_query = new Variable ''
  @_loading = new Variable 0

Template.groupMembersAddControl.rendered = ->
  @_searchHandle = Tracker.autorun =>
    if @_query()
      loading = true
      @_loading.set Tracker.nonreactive(@_loading) + 1
      Meteor.subscribe 'search-persons', @_query(), _.pluck(@data.members, '_id'),
        onReady: =>
          @_loading.set Tracker.nonreactive(@_loading) - 1 if loading
          loading = false
        onError: =>
          # TODO: Should we display some error?
          @_loading.set Tracker.nonreactive(@_loading) - 1 if loading
          loading = false
      Tracker.onInvalidate =>
        @_loading.set Tracker.nonreactive(@_loading) - 1 if loading
        loading = false

Template.groupMembersAddControl.destroyed = ->
  @_searchHandle?.stop()
  @_searchHandle = null
  @_query = null
  @_loading = null

Template.groupMembersAddControlNoResults.helpers
  noResults: ->
    template = Template.instance()

    query = template.get('_query')()

    return unless query

    searchResult = SearchResult.documents.findOne
      name: 'search-persons'
      query: query

    return unless searchResult

    not template.get('_loading')() and not (searchResult.countPersons or 0)

  email: Template.rolesControlNoResults.helpers 'email'

addMemberToGroup = (personId) ->
  Meteor.call 'add-to-group', Session.get('currentGroupId'), personId, (error, count) =>
    return FlashMessage.fromError error, true if error

    FlashMessage.success "Member added." if count

Template.groupMembersAddControlNoResults.events
  'click .invite': (event, template) ->
    # We get the email in @ (this).
    email = @

    return unless email?.match EMAIL_REGEX

    inviteUser email, Template.parentData(1).route(), (newPersonId) =>
      return true # Show success notification

    return # Make sure CoffeeScript does not return anything

Template.groupMembersAddControlLoading.helpers
  loading: ->
    Template.instance().get('_loading')()

Template.groupMembersAddControlResults.helpers
  results: ->
    template = Template.instance()

    query = template.get('_query')()

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

    # TODO: We should rerun the search with new list of existing IDs to remove added entry from results

    return # Make sure CoffeeScript does not return anything

Template.groupSettings.helpers
  canRemove: ->
    return unless @_id
    @hasRemoveAccess Meteor.person @constructor.removeAccessPersonFields()

Template.groupAdminTools.events
  'click .dropdown-trigger': (event, template) ->
    # Make sure only the trigger toggles the dropdown, by
    # excluding clicks inside the content of this dropdown
    return if $.contains template.find('.dropdown-anchor'), event.target

    template.$('.dropdown-anchor').toggle()

    return # Make sure CoffeeScript does not return anything

  'click .delete-group': (event, template) ->
    Meteor.call 'remove-group', @_id, (error, count) =>
      FlashMessage.fromError error, true if error

      return unless count

      FlashMessage.success "Group removed."
      Meteor.Router.toNew Meteor.Router.groupsPath()

    return # Make sure CoffeeScript does not return anything

Template.groupMembersAddControlInviteHint.helpers
  visible: ->
    !Template.instance().get('_query')()

Template.registerHelper 'isGroup', ->
  @ instanceof Group

Template.registerHelper 'groupPathFromId', _.bind Group.pathFromId, Group

Template.registerHelper 'groupReference', _.bind Group.reference, Group
