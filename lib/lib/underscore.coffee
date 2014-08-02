# We extend underscore with additional methods

_.mixin
  capitalize: (string) ->
    string.charAt(0).toUpperCase() + string.substring(1).toLowerCase()

  startsWith: (string, start) ->
    string.lastIndexOf(start, 0) is 0
