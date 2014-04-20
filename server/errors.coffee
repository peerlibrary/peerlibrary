class @LoggedError extends LoggedError
  @Meta
    name: 'LoggedError'
    replaceParent: true

  # A set of fields which are public and can be published to the client
  @PUBLIC_FIELDS: ->
    fields: {} # All, only admins have access

Meteor.methods
  'log-error': (errorDocument) ->
    check errorDocument, Object

    # TODO: Check whether document conforms to schema

    errorDocument.serverTime = moment.utc().toDate()

    # userAgent will not be changing, so we do not have to
    # define it as a generated field, but can just parse it here
    errorDocument.parsedUserAgent = parseUseragent errorDocument.userAgent

    personId = Meteor.personId()
    # TODO: Allow opt-out through account preferences as well
    if errorDocument.doNotTrack or not personId
      errorDocument.person = null
    else
      errorDocument.person =
        _id: personId

    LoggedError.documents.insert errorDocument

Meteor.publish 'logged-errors', ->
  currentLoggedErrors = {}
  currentPersonId = null # Just for asserts
  handleLoggedErrors = null

  removeLoggedErrors = =>
    for id of currentLoggedErrors
      delete currentLoggedErrors[id]
      @removed 'LoggedErrors', id

  publishLoggedErrors = =>
    oldHandleLoggedErrors = handleLoggedErrors
    handleLoggedErrors = LoggedError.documents.find(
      {}
    ,
      LoggedError.PUBLIC_FIELDS()
    ).observeChanges
      added: (id, fields) =>
        return if currentLoggedErrors[id]
        currentLoggedErrors[id] = true

        @added 'LoggedErrors', id, fields

      changed: (id, fields) =>
        return if not currentLoggedErrors[id]

        @changed 'LoggedErrors', id, fields

      removed: (id) =>
        return if not currentLoggedErrors[id]
        delete currentLoggedErrors[id]

        @removed 'LoggedErrors', id

    # We stop the handle after we established the new handle,
    # so that any possible changes hapenning in the meantime
    # were still processed by the old handle
    oldHandleLoggedErrors.stop() if oldHandleLoggedErrors

  handlePersons = Person.documents.find(
    _id: @personId
    isAdmin: true
  ,
    fields:
      _id: 1 # We want only id
  ).observeChanges
    added: (id, fields) =>
      # There should be only one person with the id at every given moment
      assert.equal currentPersonId, null

      currentPersonId = id
      publishLoggedErrors()

    removed: (id) =>
      # We cannot remove the person if we never added the person before
      assert.notEqual currentPersonId, null

      handleLoggedErrors.stop() if handleLoggedErrors
      handleLoggedErrors = null

      currentPersonId = null
      removeLoggedErrors()

  @ready()

  @onStop =>
    handlePersons.stop() if handlePersons
    handleLoggedErrors.stop() if handleLoggedErrors
