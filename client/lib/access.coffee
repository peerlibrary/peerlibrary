onAccessDropdownHidden = (event) ->
  # Return the access button to default state.
  $button = $(this).closest('.dropdown-trigger').find('.access-button')
  $button.addClass('tooltip')

accessButtonEventHandlers =
  'click .access-button': (event, template) ->
    $anchor = $(template.firstNode).siblings('.dropdown-anchor').first()
    $anchor.toggle()

    if $anchor.is(':visible')
      # Temporarily remove and disable tooltips on the button, because the same
      # information as in the tooltip is displayed in the dropdown content. We need
      # to remove the element manually, since we can't selectively disable/destroy
      # it just on this element through jQeury UI.
      $button = $(template.findAll '.access-button')
      tooltipId = $button.attr('aria-describedby')
      $('#' + tooltipId).remove()
      $button.removeClass('tooltip')

    else
      onAccessDropdownHidden.call($anchor, null)

    return # Make sure CoffeeScript does not return anything

Template.accessControl.rendered = ->
  $(@findAll '.dropdown-anchor').off('dropdown-hidden').on('dropdown-hidden', onAccessDropdownHidden)

Template.accessControl.helpers
  canModifyAccess: ->
    @hasAdminAccess Meteor.person @constructor.adminAccessPersonFields()

Template.accessButton.events accessButtonEventHandlers

Template.accessButton.helpers
  public: ->
    @access is @constructor.ACCESS.PUBLIC

  documentName: ->
    # Special case when having a local collection around a real collection (as in case of LocalAnnotation)
    if @constructor.Meta.collection._name is null
      documentName = @constructor.Meta.parent._name
    else
      documentName = @constructor.Meta._name

    documentName.toLowerCase()

  documentIsGroup: ->
    @ instanceof Group

Template.accessIconControl.helpers
  canModifyAccess: Template.accessControl.helpers 'canModifyAccess'

Template.accessIconButton.rendered = Template.accessButton.rendered

Template.accessIconButton.events accessButtonEventHandlers

Template.accessIconButton.helpers
  public: Template.accessButton.helpers 'public'

  documentName: Template.accessButton.helpers 'documentName'

Template.accessMenu.helpers
  canModifyAccess: ->
    @hasAdminAccess Meteor.person @constructor.adminAccessPersonFields()

Template.accessMenuPrivacyForm.events
  'change .access input:radio': (event, template) ->
    access = @constructor.ACCESS[$(template.findAll '.access input:radio:checked').val().toUpperCase()]

    return if access is @access

    # Special case when having a local collection around a real collection (as in case of LocalAnnotation)
    if @constructor.Meta.collection._name is null
      documentName = @constructor.Meta.parent._name
    else
      documentName = @constructor.Meta._name

    Meteor.call 'set-access', documentName, @_id, access, (error, changed) ->
      return FlashMessage.fromError error, true if error

      FlashMessage.success "Access changed." if changed

    return # Make sure CoffeeScript does not return anything

  'mouseenter .access .selection': (event, template) ->
    accessHover = $(event.currentTarget).find('input').val()
    $(template.findAll '.access .displayed.description').removeClass('displayed')
    $(template.findAll ".access .description.#{ accessHover }").addClass('displayed')

    return # Make sure CoffeeScript does not return anything

  'mouseleave .access .selections': (event, template) ->
    accessHover = $(template.findAll '.access input:radio:checked').val()
    $(template.findAll '.access .displayed.description').removeClass('displayed')
    $(template.findAll ".access .description.#{ accessHover }").addClass('displayed')

    return # Make sure CoffeeScript does not return anything

Template.accessMenuPrivacyForm.helpers
  public: ->
    @access is @constructor.ACCESS.PUBLIC

  private: ->
    @access is @constructor.ACCESS.PRIVATE

  documentName: Template.accessButton.helpers 'documentName'

  documentIsGroup: Template.accessButton.helpers 'documentIsGroup'

Template.accessMenuPrivacyInfo.helpers
  public: Template.accessMenuPrivacyForm.helpers 'public'

  private: Template.accessMenuPrivacyForm.helpers 'private'

  documentName: Template.accessMenuPrivacyForm.helpers 'documentName'

  documentIsGroup: Template.accessMenuPrivacyForm.helpers 'documentIsGroup'

Template.rolesControl.created = ->
  # Private access control displays a list of people, some of which might have been invited by email. We subscribe to
  # the list of people we invited so the emails appear in the list instead of IDs.
  @_personsInvitedHandle = Meteor.subscribe 'persons-invited'

Template.rolesControl.destroyed = ->
  @_personsInvitedHandle?.stop()
  @_personsInvitedHandle = null

Template.rolesControl.helpers
  showControl: ->
    return true if Template.accessControl.canModifyAccess.call @

    rolesCount = @adminGroups?.length or 0 + @adminPersons?.length or 0 + @maintainerGroups?.length or 0 + @maintainerPersons?.length or 0
    rolesCount += @readGroups?.length or 0 + @readPersons?.length or 0 if @access is ACCESS.PRIVATE

    return rolesCount > 0

  canModifyAccess: Template.accessControl.helpers 'canModifyAccess'

Template.rolesControlList.helpers
  rolesList: ->
    rolesList = []

    admins = []
    admins = admins.concat @adminGroups if @adminGroups
    admins = admins.concat @adminPersons if @adminPersons
    for admin in admins
      rolesList.push
        personOrGroup: admin
        admin: true

    maintainers = []
    maintainers = maintainers.concat @maintainerGroups if @maintainerGroups
    maintainers = maintainers.concat @maintainerPersons if @maintainerPersons
    for maintainer in maintainers
      continue if _.find rolesList, (item) ->
        item.personOrGroup._id is maintainer._id

      rolesList.push
        personOrGroup: maintainer
        maintainer: true

    if @access is ACCESS.PRIVATE
      readers = []
      readers = readers.concat @readGroups if @readGroups
      readers = readers.concat @readPersons if @readPersons
      for reader in readers
        continue if _.find rolesList, (item) ->
          item.personOrGroup._id is reader._id

        rolesList.push
          personOrGroup: reader
          readAccess: true

    # Because it is not possible to access parent data context from event handler, we map it
    # TODO: When will be possible to better access parent data context from event handler, we should use that
    _.map rolesList, (role) =>
      role._parent = @
      role

  canModifyAccess: Template.accessControl.helpers 'canModifyAccess'

changeRole = (data, newRole) ->
  oldRole = null
  oldRole = ROLES.ADMIN if data.admin
  oldRole = ROLES.MAINTAINER if data.maintainer
  oldRole = ROLES.READ_ACCESS if data.readAccess

  return if oldRole is newRole

  notification = ->
    FlashMessage.success "Permissions changed."

  unless oldRole
    notification = ->
      FlashMessage.success "#{ _.capitalize data.personOrGroup.constructor.verboseName() } added."

  else unless newRole
    notification = ->
      FlashMessage.success "#{ _.capitalize data.personOrGroup.constructor.verboseName() } removed."

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
  Meteor.call methodName, documentName, data._parent._id, data.personOrGroup._id, newRole, (error, changed) =>
    return FlashMessage.fromError error, true if error

    notification() if changed

Template.rolesControlRoleEditor.events
  'click .dropdown-trigger': (event, template) ->
    # Make sure only the trigger toggles the dropdown, by
    # excluding clicks inside the content of this dropdown
    return if $.contains template.find('.dropdown-anchor'), event.target

    $(template.findAll '.dropdown-anchor').toggle()

    return # Make sure CoffeeScript does not return anything

  'click .administrator-button': (event, template) ->
    changeRole @, ROLES.ADMIN
    $(template.findAll '.dropdown-anchor').hide()

    return # Make sure CoffeeScript does not return anything

  'click .maintainer-button': (event, template) ->
    changeRole @, ROLES.MAINTAINER
    $(template.findAll '.dropdown-anchor').hide()

    return # Make sure CoffeeScript does not return anything

  'click .read-access-button': (event, template) ->
    changeRole @, ROLES.READ_ACCESS
    $(template.findAll '.dropdown-anchor').hide()

    return # Make sure CoffeeScript does not return anything

  'click .remove-button': (event, template) ->
    changeRole @, null
    $(template.findAll '.dropdown-anchor').hide()

    return # Make sure CoffeeScript does not return anything

Template.rolesControlRoleEditor.helpers
  isPerson: ->
    @personOrGroup instanceof Person

  isGroup: ->
    @personOrGroup instanceof Group

  private: ->
    @_parent.access is ACCESS.PRIVATE

  canModifyAccess: ->
    @_parent.hasAdminAccess Meteor.person @_parent.constructor.adminAccessPersonFields()

Template.rolesControlAdd.events
  'change .add-access, keyup .add-access': (event, template) ->
    event.preventDefault()

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
      existingRoles = existingRoles.concat(_.pluck(@data.readPersons, '_id'), _.pluck(@data.readGroups, '_id')) if @data.access is ACCESS.PRIVATE

      # We are using all roles, both persons and groups, together, because
      # it is very improbable that there would be duplicate _ids
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

Template.rolesControlNoResults.helpers
  noResults: ->
    addAccessControlReactiveVariables @

    query = @_query()

    return unless query

    searchResult = SearchResult.documents.findOne
      name: 'search-persons-groups'
      query: query

    return unless searchResult

    not @_loading() and not ((searchResult.countPersons or 0) + (searchResult.countGroups or 0))

  email: ->
    addAccessControlReactiveVariables @

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

  changeRole data, if document.access is ACCESS.PRIVATE then ROLES.READ_ACCESS else ROLES.MAINTAINER

Template.addControlInviteByEmail.events
  'click .invite': (event, template) ->
    # We get the email in @ (this), but it's a String object that also has
    # the parent context attached so we first convert it to a normal string.
    email = "#{ @ }"

    return unless email?.match EMAIL_REGEX

    inviteUser email, @_parent.route(), (newPersonId) =>
      # Clear autocomplete field when we are only inviting.
      # Otherwise we leave it in so that user can click again and
      # add user to permissions.
      $inviteOnlyField = $(template.firstNode).closest('.add-control').find('.invite-only')
      if $inviteOnlyField.length
        $inviteOnlyField.val('')
        @_parent._query.set ''

      return true # Show success notification

    return # Make sure CoffeeScript does not return anything

Template.rolesControlLoading.helpers
  loading: ->
    addAccessControlReactiveVariables @

    @_loading()

  results: ->
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

Template.rolesControlResultsItem.helpers
  ifPerson: (options) ->
    if @ instanceof Person
      options.fn @
    else
      options.inverse @

Template.rolesControlResultsItem.events
  'click .add-button': (event, template) ->
    # TODO: When will be possible to better access parent data context from event handler, we should use that
    grantAccess @_parent, @

    return # Make sure CoffeeScript does not return anything

Template.rolesControlInviteHint.helpers
  visible: ->
    addAccessControlReactiveVariables @

    !@_query()

Template.rolesControlInvite.events
  'change .invite-only, keyup .invite-only': (event, template) ->
    event.preventDefault()

    # TODO: Misusing data context for a variable, add to the template instance instead: https://github.com/meteor/meteor/issues/1529
    @_query.set $(template.findAll '.invite-only').val()

    return # Make sure CoffeeScript does not return anything

# TODO: Misusing data context for a variable, use template instance instead: https://github.com/meteor/meteor/issues/1529
addAccessControlInviteOnlyReactiveVariables = (data) ->
  return if data._query
  data._query = new Variable ''
  data._newDataContext = true

Template.rolesControlInvite.created = ->
  @_rendered = false
  addAccessControlInviteOnlyReactiveVariables @data

Template.rolesControlInvite.rendered = ->
  addAccessControlInviteOnlyReactiveVariables @data

  if @_rendered and @data._newDataContext
    @_rendered = false

  delete @data._newDataContext

  return if @_rendered
  @_rendered = true

Template.rolesControlInvite.destroyed = ->
  @_rendered = false
  @data._query = null
  delete @data._newDataContext

Template.rolesControlInviteButton.helpers
  email: ->
    addAccessControlInviteOnlyReactiveVariables @

    query = @_query().trim()
    return unless query?.match EMAIL_REGEX

    # Because it is not possible to access parent data context from event handler, we store it into results
    # TODO: When will be possible to better access parent data context from event handler, we should use that
    query = new String(query)
    query._parent = @
    query
