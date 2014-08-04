# We extend underscore with additional methods

_.mixin
  capitalize: (string) ->
    string.charAt(0).toUpperCase() + string.substring(1).toLowerCase()

  startsWith: (string, start) ->
    string.lastIndexOf(start, 0) is 0

  # Ensures that string ends with dot if it does not already end with some punctuation
  ensureSentence: (string) ->
    string = string?.replace /\s+$/, ''
    if string and string.charAt(string.length - 1) not in ['.', '?', '!', ',', ';', ')']
      "#{ string }."
    else
      string

  isPlainObject = (obj) ->
    if not _.isObject(obj) or _.isArray(obj) or _.isFunction(obj)
      return false

    if obj.constructor isnt Object
      return false

    return true
