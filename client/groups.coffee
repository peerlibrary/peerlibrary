Template.groups.helpers
  catalogSettings: ->
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

Tracker.autorun ->
  if Session.equals 'groupsActive', true
    Meteor.subscribe 'my-groups'

Template.groups.events
  'submit .add-group': (event, template) ->
    event.preventDefault()

    name = template.$('.name').val().trim()
    return unless name

    Meteor.call 'create-group', name, (error, groupId) =>
      return FlashMessage.fromError error, true if error

      FlashMessage.success "Group created."

    return # Make sure CoffeeScript does not return anything

Template.myGroups.helpers
  myGroups: ->
    Group.documents.find
      _id:
        $in: _.pluck Meteor.person(inGroups: 1)?.inGroups, '_id'
    ,
      sort: [
        ['name', 'asc']
      ]
      fields:
        searchResult: 0

Template.groupCatalogItem.helpers
  countDescription: ->
    return unless @_id
    if @membersCount is 1 then "1 member" else "#{ @membersCount } members"

  public: ->
    return unless @_id
    @access is ACCESS.OPEN

  private: ->
    return unless @_id
    @access is ACCESS.PRIVATE

Editable.template Template.groupCatalogItemName, ->
  data = Template.currentData()
  return unless data
  # TODO: Not all necessary fields for correct access check are present in search results/catalog, we should preprocess permissions this in a middleware and send computed permission as a boolean flag
  data.hasMaintainerAccess Meteor.person data.constructor.maintainerAccessPersonFields()
,
  (name) ->
    name = name.trim()
    return unless name
    Meteor.call 'group-set-name', Template.currentData()._id, name, (error, count) ->
      return FlashMessage.fromError error, true if error
,
  "Enter group name"
,
  false

EnableCatalogItemLink Template.groupCatalogItem
