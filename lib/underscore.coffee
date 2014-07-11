# We extend underscore with additional methods

_.mixin
  capitalize: (string) ->
    string.charAt(0).toUpperCase() + string.substring(1).toLowerCase()
