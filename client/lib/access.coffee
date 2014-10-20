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
      $button = template.$('.access-button')
      tooltipId = $button.attr('aria-describedby')
      $('#' + tooltipId).remove()
      $button.removeClass('tooltip')

    else
      onAccessDropdownHidden.call($anchor, null)

    return # Make sure CoffeeScript does not return anything

Template.accessControl.rendered = ->
  @$('.dropdown-anchor').off('dropdown-hidden').on('dropdown-hidden', onAccessDropdownHidden)

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
    access = @constructor.ACCESS[template.$('.access input:radio:checked').val().toUpperCase()]

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
    template.$('.access .displayed.description').removeClass('displayed')
    template.$(".access .description.#{ accessHover }").addClass('displayed')

    return # Make sure CoffeeScript does not return anything

  'mouseleave .access .selections': (event, template) ->
    accessHover = template.$('.access input:radio:checked').val()
    template.$('.access .displayed.description').removeClass('displayed')
    template.$(".access .description.#{ accessHover }").addClass('displayed')

    return # Make sure CoffeeScript does not return anything

Template.accessMenuPrivacyForm.helpers
  public: ->
    @access is @constructor.ACCESS.PUBLIC

  private: ->
    @access is @constructor.ACCESS.PRIVATE

  documentName: Template.accessButton.helpers 'documentName'

Template.accessMenuPrivacyInfo.helpers
  public: Template.accessMenuPrivacyForm.helpers 'public'

  private: Template.accessMenuPrivacyForm.helpers 'private'

  documentName: Template.accessMenuPrivacyForm.helpers 'documentName'

Template.rolesControl.created = ->
  # Private access control displays a list of people, some of which might have been invited by email. We subscribe to
  # the list of people we invited so the emails appear in the list instead of IDs.
  @_personsInvitedHandle = Meteor.subscribe 'persons-invited'

Template.rolesControl.destroyed = ->
  @_personsInvitedHandle?.stop()
  @_personsInvitedHandle = null

Template.rolesControl.helpers
  showControl: ->
    return true if Template.accessControl.helpers('canModifyAccess').call @

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
        role: ROLES.ADMIN

    maintainers = []
    maintainers = maintainers.concat @maintainerGroups if @maintainerGroups
    maintainers = maintainers.concat @maintainerPersons if @maintainerPersons
    for maintainer in maintainers
      continue if _.find rolesList, (item) ->
        item.personOrGroup._id is maintainer._id

      rolesList.push
        personOrGroup: maintainer
        maintainer: true
        role: ROLES.MAINTAINER

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
          role: ROLES.READ_ACCESS

    rolesList

  canModifyAccess: Template.accessControl.helpers 'canModifyAccess'

changeRoleFromRolesListElement = (document, rolesListElement, newRole) ->
  changeRole document, rolesListElement.personOrGroup, rolesListElement.role, newRole

changeRole = (document, personOrGroup, oldRole, newRole) ->
  return if oldRole is newRole

  notification = ->
    FlashMessage.success "Permissions changed."

  unless oldRole
    notification = ->
      FlashMessage.success "#{ _.capitalize personOrGroup.constructor.verboseName() } added."

  else unless newRole
    notification = ->
      FlashMessage.success "#{ _.capitalize personOrGroup.constructor.verboseName() } removed."

  if personOrGroup instanceof Person
    methodName = 'set-role-for-person'
  else if personOrGroup instanceof Group
    methodName = 'set-role-for-group'
  else
    assert false

  # Special case when having a local collection around a real collection (as in case of LocalAnnotation)
  if document.constructor.Meta.collection._name is null
    documentName = document.constructor.Meta.parent._name
  else
    documentName = document.constructor.Meta._name

  Meteor.call methodName, documentName, document._id, personOrGroup._id, newRole, (error, changed) =>
    return FlashMessage.fromError error, true if error

    notification() if changed

Template.rolesControlRoleEditor.events
  'click .dropdown-trigger': (event, template) ->
    # Make sure only the trigger toggles the dropdown, by
    # excluding clicks inside the content of this dropdown
    return if $.contains template.find('.dropdown-anchor'), event.target

    template.$('.dropdown-anchor').toggle()

    return # Make sure CoffeeScript does not return anything

  'click .administrator-button': (event, template) ->
    changeRoleFromRolesListElement Template.parentData(1), @, ROLES.ADMIN
    template.$('.dropdown-anchor').hide()

    return # Make sure CoffeeScript does not return anything

  'click .maintainer-button': (event, template) ->
    changeRoleFromRolesListElement Template.parentData(1), @, ROLES.MAINTAINER
    template.$('.dropdown-anchor').hide()

    return # Make sure CoffeeScript does not return anything

  'click .read-access-button': (event, template) ->
    changeRoleFromRolesListElement Template.parentData(1), @, ROLES.READ_ACCESS
    template.$('.dropdown-anchor').hide()

    return # Make sure CoffeeScript does not return anything

  'click .remove-button': (event, template) ->
    changeRoleFromRolesListElement Template.parentData(1), @, null
    template.$('.dropdown-anchor').hide()

    return # Make sure CoffeeScript does not return anything

Template.rolesControlRoleEditor.helpers
  private: ->
    Template.parentData(1).access is ACCESS.PRIVATE

  canModifyAccess: ->
    Template.parentData(1).hasAdminAccess Meteor.person Template.parentData(1).constructor.adminAccessPersonFields()

Template.rolesControlAdd.created = ->
  @_searchHandle = null
  @_query = new Variable ''
  @_loading = new Variable 0

Template.rolesControlAdd.rendered = ->
  @_searchHandle = Tracker.autorun =>
    if @_query()
      loading = true
      @_loading.set Tracker.nonreactive(@_loading) + 1

      existingRoles = _.pluck(@data.adminPersons, '_id').concat(
        _.pluck(@data.adminGroups, '_id'),
        _.pluck(@data.maintainerPersons, '_id'),
        _.pluck(@data.maintainerGroups, '_id'),
      )
      if @data.access is ACCESS.PRIVATE
        existingRoles = existingRoles.concat(
          _.pluck(@data.readPersons, '_id'),
          _.pluck(@data.readGroups, '_id'),
        )

      # We are using all roles, both persons and groups, together, because
      # it is very improbable that there would be duplicate _ids
      Meteor.subscribe 'search-persons-groups', @_query(), existingRoles,
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

Template.rolesControlAdd.destroyed = ->
  @_searchHandle?.stop()
  @_searchHandle = null
  @_query = null
  @_loading = null

Template.rolesControlAdd.events
  'change .add-access, keyup .add-access': (event, template) ->
    event.preventDefault()

    template.get('_query').set template.$('.add-access').val().trim()

    return # Make sure CoffeeScript does not return anything

Template.rolesControlNoResults.helpers
  noResults: ->
    template = Template.instance()

    query = template.get('_query')()

    return unless query

    searchResult = SearchResult.documents.findOne
      name: 'search-persons-groups'
      query: query

    return unless searchResult

    not template.get('_loading')() and not ((searchResult.countPersons or 0) + (searchResult.countGroups or 0))

  email: ->
    template = Template.instance()

    query = template.get('_query')()

    return unless query?.match EMAIL_REGEX

    query

grantAccess = (document, personOrGroup) ->
  changeRole document, personOrGroup, null, if document.access is ACCESS.PRIVATE then ROLES.READ_ACCESS else ROLES.MAINTAINER

Template.addControlInviteByEmail.events
  'click .invite': (event, template) ->
    # We get the email in @ (this).
    email = @

    return unless email?.match EMAIL_REGEX

    inviteUser email, Template.parentData(1).route(), (newPersonId) =>
      # Clear autocomplete field when we are only inviting.
      # Otherwise we leave it in so that user can click again and
      # add user to permissions.
      $inviteOnlyField = $(template.firstNode).closest('.add-control').find('.invite-only')
      if $inviteOnlyField.length
        $inviteOnlyField.val('')
        template.get('_query').set ''

      return true # Show success notification

    return # Make sure CoffeeScript does not return anything

Template.rolesControlLoading.helpers
  loading: ->
    Template.instance().get('_loading')()

Template.rolesControlResults.helpers
  results: ->
    template = Template.instance()

    query = template.get('_query')()

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

    persons.concat groups

Template.rolesControlResultsItem.events
  'click .add-button': (event, template) ->
    grantAccess Template.parentData(1), @

    return # Make sure CoffeeScript does not return anything

Template.rolesControlInviteHint.helpers
  visible: ->
    !Template.instance().get('_query')()

Template.rolesControlInvite.events
  'change .invite-only, keyup .invite-only': (event, template) ->
    event.preventDefault()

    template.get('_query').set template.$('.invite-only').val().trim()

    return # Make sure CoffeeScript does not return anything

Template.rolesControlInvite.created = ->
  @_query = new Variable ''

Template.rolesControlInvite.destroyed = ->
  @_query = null

Template.rolesControlInviteButton.helpers
  email: ->
    template = Template.instance()

    query = template.get('_query')()

    return unless query?.match EMAIL_REGEX

    query
