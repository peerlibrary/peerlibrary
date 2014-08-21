@validateArgument = (argumentValue, match, argumentName) ->
  throw new Error "Argument name not set." unless argumentName
  try
    check argumentValue, match
  catch error
    throw new ValidationError error.message, argumentName

class @ValidationError extends Meteor.Error
  constructor: (reason, argumentName) ->
    assert argumentName
    error = 400
    details = "Argument: #{ argumentName }"
    super error, reason, details
