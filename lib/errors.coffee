@validateArgument = (argumentName, argumentValue, match) ->
  throw new Error "Argument name not set." unless argumentName
  try
    check argumentValue, match
  catch error
    throw new ValidationError error.message, argumentName

# While extending Error directly does not work, because instanceof check
# does not work, extending an error made with makeErrorType further works.
class @ValidationError extends Meteor.Error
  constructor: (reason, argumentName) ->
    assert argumentName
    error = 400
    details = "Argument: #{ argumentName }"
    super error, reason, details
