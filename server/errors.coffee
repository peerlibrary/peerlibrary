LoggedErrors.allow
  insert: (userId, doc) ->
    # TODO: Check whether inserted document conforms to schema
    true

LoggedErrors.before.insert (userId, doc) ->
    doc.serverTime = moment.utc().toDate()

    # userAgent will not be changing, so we do not have to
    # define it as a generated field, but can just parse it
    doc.parsedUserAgent = parseUseragent doc.userAgent

    personId = Meteor.personId()
    # TODO: Allow opt-out through account preferences as well
    if doc.doNotTrack or not personId
      doc.person = null
    else
      doc.person =
        _id: personId

    true

Meteor.publish 'logged-errors', ->
  # TODO: Make this reactive
  person = Persons.findOne
    _id: @personId
  ,
    isAdmin: 1

  return unless person?.isAdmin

  LoggedErrors.find {}