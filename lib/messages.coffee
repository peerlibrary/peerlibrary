# Session variable wrapper for info/error messages
class @FormMessages
  fields: [''] # Empty string represents global message which always exists
  messageType:
    ERROR: 'errorMessage'
    INFO: 'infoMessage'

  constructor: (prefix) ->
    @prefix = prefix or "form-#{ Random.id() }-"

  _set: (messageType, field, value) =>
    field = '' unless field
    Session.set @prefix + messageType + field, value

  _get: (messageType, field) =>
    field = '' unless field
    throw new Error "Field #{ field } does not exist" unless field in @fields
    Session.get @prefix + messageType + field

  _registerField: (field) =>
    @fields.push field unless field in @fields

  # Returns object containing both info and error messages
  get: (field) =>
    return {} =
      errorMessage: @getErrorMessage field
      infoMessage: @getInfoMessage field

  # Resets both info and error messages
  resetMessages: (field) =>
    if !field and field isnt ''
      fields = @fields
    else
      fields = [field]
    for field in fields
      @_set @messageType.INFO, field, ''
      @_set @messageType.ERROR, field, ''

  # Checks if given field is valid. If no field is given, checks if entire form is valid.
  isValid: (field) =>
    return not @getErrorMessage field if field
    for field in @fields
      continue unless field
      return false unless @isValid field
    true

  # Converts argument name to field name
  mapArgumentToField: (argumentName) =>
    # For now we keep those equal
    argumentName

  # Read error message and field from given error object
  setError: (error) =>
    if error instanceof Meteor.Error
      # We get field value from error details
      if _.startsWith error.details, 'Argument: '
        argument = error.details.substring 'Argument: '.length
      else
        argument = ''
      @setErrorMessage error.reason, @mapArgumentToField argument
    else if error instanceof Error
      @setErrorMessage error.message
    else
      @setErrorMessage error.toString()

  # Sets error message for given field or global error message if field is not set
  setErrorMessage: (message, field) =>
    @_registerField field if field
    @_set @messageType.INFO, field, ''
    @_set @messageType.ERROR, field, message

  # Sets info message for given field or global info message if field is not set
  setInfoMessage: (message, field) =>
    @_registerField field if field
    @_set @messageType.ERROR, field, ''
    @_set @messageType.INFO, field, message

  # Gets error message for given field or global error message if field is not set
  getErrorMessage: (field) =>
    @_registerField field if field
    @_get @messageType.ERROR, field

  # Gets info message for given field or global info message if filed is not set
  getInfoMessage: (field) =>
    @_registerField field if field
    @_get @messageType.INFO, field

