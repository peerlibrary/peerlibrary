@validateArgument = (argumentValue, match, argumentName) ->
  try
    check argumentValue, match
  catch error
    throw new ValidationError error.error, error.message, argumentName

class @ValidationError extends Meteor.Error
  constructor: (error, reason, argumentName) ->
    details = "Argument: #{ argumentName or '' }"
    super error, reason, details

