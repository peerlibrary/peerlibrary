Errors.allow
  insert: (userId, doc) ->
    # TODO: Check whether inserted document conforms to schema
    # TODO: Timestamp the error
    # TODO: Add userId to the error - is this privacy sensitive?
    true

Meteor.publish 'errors', ->
  # TODO: Make this reactive
  person = Persons.findOne
    _id: @personId
  ,
    isAdmin: 1

  return unless person?.isAdmin

  Errors.find {}