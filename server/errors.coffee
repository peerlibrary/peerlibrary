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
  validateArgument 'limit', limit, PositiveNumber
  validateArgument 'filter', filter, OptionalOrNull String
  validateArgument 'sortIndex', sortIndex, OptionalOrNull Number
  validateArgument 'sortIndex', sortIndex, Match.Where (sortIndex) ->
    not _.isNumber(sortIndex) or 0 <= sortIndex < LoggedError.PUBLISH_CATALOG_SORT.length

  findQuery = {}
  findQuery = createQueryCriteria(filter, 'serverTime') if filter

  sort = if _.isNumber sortIndex then LoggedError.PUBLISH_CATALOG_SORT[sortIndex].sort else null

  @related (person) ->
    return unless person?.isAdmin
    # We store related fields so that they are available in middlewares.
    @set 'person', person

    searchPublish @, 'logged-errors', [filter, sortIndex],
      cursor: LoggedError.documents.find findQuery,
        limit: limit
        fields: LoggedError.PUBLISH_CATALOG_FIELDS().fields
        sort: sort
  ,
    Person.documents.find
      _id: @personId
    ,
      fields:
        # _id field is implicitly added
        isAdmin: 1

ensureCatalogSortIndexes LoggedError