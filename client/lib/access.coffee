Template.accessControl.events
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

Template.accessControl.documentName = ->
  # Special case when having a local collection around a real collection (as in case of LocalAnnotation)
  if @constructor.Meta.collection._name is null
    documentName = @constructor.Meta.parent._name
  else
    documentName = @constructor.Meta._name

  documentName.toLowerCase()

Template.accessControl.public = ->
  @access is @constructor.ACCESS.PUBLIC

Template.accessControl.private = ->
  @access is @constructor.ACCESS.PRIVATE

Template.privateAccessControl.created = ->
  # Private access control displays a list of people, some of which might have been invited by email. We subscribe to
  # the list of people we invited so the emails appear in the list instead of IDs.
  @_personsInvitedHandle = Meteor.subscribe 'persons-invited'

Template.privateAccessControl.destroyed = ->
  @_personsInvitedHandle?.stop()
  @_personsInvitedHandle = null

Template.privateAccessControlAdd.events
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

Template.privateAccessControlAdd.created = ->
  @_searchHandle = null

  addAccessControlReactiveVariables @data

Template.privateAccessControlAdd.rendered = ->
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
      Meteor.subscribe 'search-persons-groups', @data._query(), _.pluck(@data.readPersons, '_id').concat(_.pluck(@data.readGroups, '_id')),
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

Template.privateAccessControlAdd.destroyed = ->
  @_searchHandle?.stop()
  @_searchHandle = null

  @data._query = null
  @data._loading = null

  delete @data._newDataContext

Template.privateAccessControlNoResults.noResults = ->
  addAccessControlReactiveVariables @

  query = @_query()

  return unless query

  searchResult = SearchResult.documents.findOne
    name: 'search-persons-groups'
    query: query

  return unless searchResult

  not @_loading() and not ((searchResult.countPersons or 0) + (searchResult.countGroups or 0))

Template.privateAccessControlNoResults.email = ->
  query = @_query().trim()
  return unless query?.match EMAIL_REGEX

  # Because it is not possible to access parent data context from event handler, we store it into results
  # TODO: When will be possible to better access parent data context from event handler, we should use that
  query = new String(query)
  query._parent = @
  query

grantAccess = (document, personOrGroup) ->
  if personOrGroup instanceof Person
    methodName = 'grant-read-access-to-person'
  else if personOrGroup instanceof Group
    methodName = 'grant-read-access-to-group'
  else
    assert false

  # Special case when having a local collection around a real collection (as in case of LocalAnnotation)
  if document.constructor.Meta.collection._name is null
    documentName = document.constructor.Meta.parent._name
  else
    documentName = document.constructor.Meta._name

  Meteor.call methodName, documentName, document._id, personOrGroup._id, (error, count) =>
    return Notify.meteorError error, true if error

    Notify.success "#{ _.capitalize personOrGroup.constructor.verboseName() } added." if count

Template.privateAccessControlNoResults.events
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

Template.privateAccessControlLoading.loading = ->
  addAccessControlReactiveVariables @

  @_loading()

Template.privateAccessControlResults.results = ->
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

Template.privateAccessControlList.events
  'click .remove-button': (e, template) ->
    if @ instanceof Person
      methodName = 'revoke-read-access-for-person'
    else if @ instanceof Group
      methodName = 'revoke-read-access-for-group'
    else
      assert false

    # Special case when having a local collection around a real collection (as in case of LocalAnnotation)
    if @_parent.constructor.Meta.collection._name is null
      documentName = @_parent.constructor.Meta.parent._name
    else
      documentName = @_parent.constructor.Meta._name

    # TODO: When will be possible to better access parent data context from event handler, we should use that
    Meteor.call methodName, documentName, @_parent._id, @_id, (error, count) =>
      return Notify.meteorError error, true if error

      Notify.success "#{ _.capitalize @constructor.verboseName() } removed." if count

    return # Make sure CoffeeScript does not return anything

Template.privateAccessControlList.readPersonsList = ->
  # Because it is not possible to access parent data context from event handler, we map it
  # TODO: When will be possible to better access parent data context from event handler, we should use that
  _.map @readPersons, (person) =>
    person._parent = @
    person

Template.privateAccessControlList.readGroupsList = ->
  # Because it is not possible to access parent data context from event handler, we map it
  # TODO: When will be possible to better access parent data context from event handler, we should use that
  _.map @readGroups, (group) =>
    group._parent = @
    group

Template.privateAccessControlResultsItem.ifPerson = (options) ->
  if @ instanceof Person
    options.fn @
  else
    options.inverse @

Template.privateAccessControlResultsItem.events
  'click .add-button': (e, template) ->

    # TODO: When will be possible to better access parent data context from event handler, we should use that
    grantAccess @_parent, @

    return # Make sure CoffeeScript does not return anything
