Template.groups.catalogSettings = ->
  subscription: 'groups'
  documentClass: Group
  variables:
    active: 'groupsActive'
    ready: 'currentGroupsReady'
    loading: 'currentGroupsLoading'
    count: 'currentGroupsCount'
    filter: 'currentGroupsFilter'
    limit: 'currentGroupsLimit'
    limitIncreasing: 'currentGroupsLimitIncreasing'
    sort: 'currentGroupsSort'
  signedInNoDocumentsMessage: "Create the first using the form on the right."
  signedOutNoDocumentsMessage: "Sign in and create the first."

Deps.autorun ->
  if Session.equals 'groupsActive', true
    Meteor.subscribe 'my-groups'

Template.groups.events
  'submit .add-group': (event, template) ->
    event.preventDefault()

    name = $(template.findAll '.name').val().trim()
    return unless name

    Meteor.call 'create-group', name, (error, groupId) =>
      return FlashMessage.fromError error, true if error

      FlashMessage.success "Group created."

    return # Make sure CoffeeScript does not return anything

Template.myGroups.myGroups = ->
  Group.documents.find
    _id:
      $in: _.pluck Meteor.person(inGroups: 1)?.inGroups, '_id'
  ,
    sort: [
      ['name', 'asc']
    ]
    fields:
      searchResult: 0

Template.groupCatalogItem.countDescription = ->
  if @membersCount is 1 then "1 member" else "#{ @membersCount } members"

Template.groupCatalogItem.public = ->
  @access is ACCESS.OPEN

Template.groupCatalogItem.private = ->
  @access is ACCESS.PRIVATE

Editable.template Template.groupCatalogItemName, ->
  @data.hasMaintainerAccess Meteor.person @data.constructor.maintainerAccessPersonFields()
,
  (name) ->
    Meteor.call 'group-set-name', @data._id, name, (error, count) ->
      return FlashMessage.fromError error, true if error
,
  "Enter group name"
,
  false

EnableCatalogItemLink Template.groupCatalogItem
