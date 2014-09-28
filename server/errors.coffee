class @LoggedError extends LoggedError
  @Meta
    name: 'LoggedError'
    replaceParent: true

  # A set of fields which are public and can be published to the client
  @PUBLISH_FIELDS: ->
    fields: {} # All, only admins have access

Meteor.methods
  'log-error': methodWrap (errorDocument) ->
    validateArgument 'errorDocument', errorDocument, Object

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

new PublishEndpoint 'logged-errors', ->
  @related (person) ->
    return unless person?.isAdmin

    LoggedError.documents.find {},
      fields: LoggedError.PUBLISH_FIELDS().fields
      # 30 most recently received errors
      limit: 30
      sort: [
        ['serverTime', 'desc']
      ]
  ,
    Person.documents.find
      _id: @personId
    ,
      fields:
        # _id field is implicitly added
        isAdmin: 1

LoggedError.Meta.collection._ensureIndex
  serverTime: -1
