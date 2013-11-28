Errors.allow
  insert: (userId, doc) ->
    # TODO: Check whether inserted document conforms to schema
    # TODO: Timestamp the error
    # TODO: Add userId to the error - is this privacy sensitive?
    true

Meteor.publish 'errors', ->
  # TODO: Only allow admin users to subscribe to Errors
  Errors.find {}