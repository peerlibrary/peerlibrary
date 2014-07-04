Template.accessControl.canModifyAccess = ->
  @hasAdminAccess Meteor.person @constructor.adminAccessPersonFields()

Template.accessControlPrivacyForm.events
  'change .access input:radio': (e, template) ->
    access = @constructor.ACCESS[$(template.findAll '.access input:radio:checked').val().toUpperCase()]

    return if access is @access

    # Special case when having a local collection around a real collection (as in case of LocalAnnotation)
    if @constructor.Meta.collection._name is null
      documentName = @constructor.Meta.parent._name
    else
      documentName = @constructor.Meta._name

    Meteor.call 'set-access', documentName, @_id, access, (error, count) ->
      return Notify.meteorError error, true if error

      Notify.success "Access changed." if count

    return # Make sure CoffeeScript does not return anything

  'mouseenter .access .selection': (e, template) ->
    accessHover = $(e.currentTarget).find('input').val()
    $(template.findAll '.access .displayed.description').removeClass('displayed')
    $(template.findAll ".access .description.#{accessHover}").addClass('displayed')

    return # Make sure CoffeeScript does not return anything

  'mouseleave .access .selections': (e, template) ->
    accessHover = $(template.findAll '.access input:radio:checked').val()
    $(template.findAll '.access .displayed.description').removeClass('displayed')
    $(template.findAll ".access .description.#{accessHover}").addClass('displayed')

    return # Make sure CoffeeScript does not return anything

Template.accessControlPrivacyForm.public = ->
  @access is @constructor.ACCESS.PUBLIC

Template.accessControlPrivacyForm.private = ->
  @access is @constructor.ACCESS.PRIVATE

Template.accessControlPrivacyForm.documentName = ->
  # Special case when having a local collection around a real collection (as in case of LocalAnnotation)
  if @constructor.Meta.collection._name is null
    documentName = @constructor.Meta.parent._name
  else
    documentName = @constructor.Meta._name

  documentName.toLowerCase()

Template.accessControlPrivacyInfo.public = Template.accessControlPrivacyForm.public

Template.accessControlPrivacyInfo.private = Template.accessControlPrivacyForm.private

Template.accessControlPrivacyInfo.documentName = Template.accessControlPrivacyForm.documentName

Template.rolesControl.created = ->
  # Private access control displays a list of people, some of which might have been invited by email. We subscribe to
  # the list of people we invited so the emails appear in the list instead of IDs.
  @_personsInvitedHandle = Meteor.subscribe 'persons-invited'

Template.rolesControl.destroyed = ->
  @_personsInvitedHandle?.stop()
  @_personsInvitedHandle = null

Template.rolesControl.showControl = ->
  return true if Template.accessControl.canModifyAccess.call @

  @adminGroups?.length > 0 or @adminPersons?.length > 0 or
  @maintainerGroups?.length > 0 or @maintainerPersons?.length > 0 or
  @access is ACCESS.PRIVATE and (@readGroups?.length > 0 or @readPersons?.length > 0)

Template.rolesControl.canModifyAccess = Template.accessControl.canModifyAccess

Template.rolesControlList.rolesList = ->

  rolesList = []

  admins = []
  admins = admins.concat(@adminGroups) if @adminGroups
  admins = admins.concat(@adminPersons) if @adminPersons
  admins.forEach (admin, index) ->
    rolesList.push
      personOrGroup: admin
      admin: true

  maintainers = []
  maintainers = maintainers.concat(@maintainerGroups) if @maintainerGroups
  maintainers = maintainers.concat(@maintainerPersons) if @maintainerPersons
  maintainers.forEach (maintainer, index) ->
    return if _.find rolesList, (item) ->
      item.personOrGroup._id is maintainer._id

    rolesList.push
      personOrGroup: maintainer
      maintainer: true

  if @access is ACCESS.PRIVATE
    readers = []
    readers = readers.concat(@readGroups) if @readGroups
    readers = readers.concat(@readPersons) if @readPersons
    readers.forEach (reader, index) ->
      return if _.find rolesList, (item) ->
        item.personOrGroup._id is reader._id

      rolesList.push
        personOrGroup: reader
        readAccess: true

  # Because it is not possible to access parent data context from event handler, we map it
  # TODO: When will be possible to better access parent data context from event handler, we should use that
  _.map rolesList, (role) =>
    role._parent = @
    role

Template.rolesControlList.canModifyAccess = Template.accessControl.canModifyAccess

changeRole = (data, newRole) ->
  oldRole = null
  oldRole = ROLES.ADMIN if data.admin
  oldRole = ROLES.MAINTAINER if data.maintainer
  oldRole = ROLES.READ_ACCESS if data.readAccess

  return if oldRole is newRole

  notification = () ->
    Notify.success "Rights changed."

  unless oldRole
    notification = () ->
      Notify.success "#{ _.capitalize data.personOrGroup.constructor.verboseName() } added."

  else unless newRole
    notification = () ->
      Notify.success "#{ _.capitalize data.personOrGroup.constructor.verboseName() } removed."

  if data.personOrGroup instanceof Person
    methodName = 'set-role-for-person'
  else if data.personOrGroup instanceof Group
    methodName = 'set-role-for-group'
  else
    assert false

  # Special case when having a local collection around a real collection (as in case of LocalAnnotation)
  if data._parent.constructor.Meta.collection._name is null
    documentName = data._parent.constructor.Meta.parent._name
  else
    documentName = data._parent.constructor.Meta._name

  # TODO: When will be possible to better access parent data context from event handler, we should use that
  Meteor.call methodName, documentName, data._parent._id, data.personOrGroup._id, newRole, (error, count) =>
    return Notify.meteorError error, true if error

    notification() if count

Template.rolesControlRoleEditor.events
  'click .dropdown-trigger': (e, template) ->
    # Make sure only the trigger toggles the dropdown
    return if $(e.target).closest('.dropdown-anchor').length

    $(template.findAll '.dropdown-anchor').toggle()

    return # Make sure CoffeeScript does not return anything

  'click .administrator-button': (e, template) ->
    changeRole @, ROLES.ADMIN
    $(template.findAll '.dropdown-anchor').hide()

    return # Make sure CoffeeScript does not return anything

  'click .maintainer-button': (e, template) ->
    changeRole @, ROLES.MAINTAINER
    $(template.findAll '.dropdown-anchor').hide()

    return # Make sure CoffeeScript does not return anything

  'click .read-access-button': (e, template) ->
    changeRole @, ROLES.READ_ACCESS
    $(template.findAll '.dropdown-anchor').hide()

    return # Make sure CoffeeScript does not return anything

  'click .remove-button': (e, template) ->
    changeRole @, null
    $(template.findAll '.dropdown-anchor').hide()

    return # Make sure CoffeeScript does not return anything

Template.rolesControlRoleEditor.isPerson = ->
  @personOrGroup instanceof Person

Template.rolesControlRoleEditor.isGroup = ->
  @personOrGroup instanceof Group

Template.rolesControlRoleEditor.private = ->
  @_parent.access is ACCESS.PRIVATE

Template.rolesControlRoleEditor.canModifyAccess = ->
  @_parent.hasAdminAccess Meteor.person @_parent.constructor.adminAccessPersonFields()

Template.rolesControlAdd.events
  'change .add-access, keyup .add-access': (e, template) ->
    e.preventDefault()

    # TODO: Misusing data context for a variable, add to the template instance instead: https://github.com/meteor/meteor/issues/1529
    @_query.set $(template.findAll '.add-access').val()

    return # Make sure CoffeeScript does not return anything

# TODO: Misusing data context for a variable, use template instance instead: https://github.com/meteor/meteor/issues/1529
addAccessControlReactiveVariables = (data) ->
  if data._query
    assert data._loading
    return

  data._query = new Variable ''
  data._loading = new Variable 0

  data._newDataContext = true

Template.rolesControlAdd.created = ->
  @_searchHandle = null

  addAccessControlReactiveVariables @data

Template.rolesControlAdd.rendered = ->
  addAccessControlReactiveVariables @data

  if @_searchHandle and @data._newDataContext
    @_searchHandle.stop()
    @_searchHandle = null

  delete @data._newDataContext

  return if @_searchHandle
  @_searchHandle = Deps.autorun =>
    if @data._query()
      loading = true
      @data._loading.set Deps.nonreactive(@data._loading) + 1

      existingRoles = _.pluck(@data.adminPersons, '_id').concat(_.pluck(@data.adminGroups, '_id'),
        _.pluck(@data.maintainerPersons, '_id'), _.pluck(@data.maintainerGroups, '_id'))
      existingRoles = existingRoles.concat(_.pluck(@data.readPersons, '_id'), _.pluck(@data.readGroups, '_id')) if (@data.access is ACCESS.PRIVATE)

      Meteor.subscribe 'search-persons-groups', @data._query(), existingRoles,
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

Template.rolesControlAdd.destroyed = ->
  @_searchHandle?.stop()
  @_searchHandle = null

  @data._query = null
  @data._loading = null

  delete @data._newDataContext

Template.rolesControlNoResults.noResults = ->
  addAccessControlReactiveVariables @

  query = @_query()

  return unless query

  searchResult = SearchResult.documents.findOne
    name: 'search-persons-groups'
    query: query

  return unless searchResult

  not @_loading() and not ((searchResult.countPersons or 0) + (searchResult.countGroups or 0))

Template.rolesControlNoResults.email = ->
  query = @_query().trim()
  return unless query?.match EMAIL_REGEX

  # Because it is not possible to access parent data context from event handler, we store it into results
  # TODO: When will be possible to better access parent data context from event handler, we should use that
  query = new String(query)
  query._parent = @
  query

grantAccess = (document, personOrGroup) ->
  data =
    _parent: document
    personOrGroup: personOrGroup

  switch document.access
    when ACCESS.PRIVATE then changeRole data, ROLES.READ_ACCESS
    else changeRole data, ROLES.MAINTAINER

Template.rolesControlNoResults.events
  'click .add-and-invite': (e, template) ->

    # We get the email in @ (this), but it's a String object that also has
    # the parent context attached so we first convert it to a normal string.
    email = "#{ @ }"

    return unless email?.match EMAIL_REGEX

    inviteUser email, null, (newPersonId) =>
      grantAccess @_parent, new Person
        _id: newPersonId

      return true # Show success notification

    return # Make sure CoffeeScript does not return anything

Template.rolesControlLoading.loading = ->
  addAccessControlReactiveVariables @

  @_loading()

Template.rolesControlResults.results = ->
  addAccessControlReactiveVariables @

  query = @_query()

  return unless query

  searchResult = SearchResult.documents.findOne
    name: 'search-persons-groups'
    query: query

  return unless searchResult

  personsLimit = Math.round(5 * searchResult.countPersons / (searchResult.countPersons + searchResult.countGroups))
  groupsLimit = 5 - personsLimit

  if personsLimit
    persons = Person.documents.find(
      'searchResult._id': searchResult._id
    ,
      sort: [
        ['searchResult.order', 'asc']
      ]
      limit: personsLimit
    ).fetch()
  else
    persons = []

  if groupsLimit
    groups = Group.documents.find(
      'searchResult._id': searchResult._id
    ,
      sort: [
        ['searchResult.order', 'asc']
      ]
      limit: groupsLimit
    ).fetch()
  else
    groups = []

  results = persons.concat groups

  # Because it is not possible to access parent data context from event handler, we store it into results
  # TODO: When will be possible to better access parent data context from event handler, we should use that
  _.map results, (result) =>
    result._parent = @
    result


Template.rolesControlResultsItem.ifPerson = (options) ->
  if @ instanceof Person
    options.fn @
  else
    options.inverse @

Template.rolesControlResultsItem.events
  'click .add-button': (e, template) ->

    # TODO: When will be possible to better access parent data context from event handler, we should use that
    grantAccess @_parent, @

    return # Make sure CoffeeScript does not return anything
