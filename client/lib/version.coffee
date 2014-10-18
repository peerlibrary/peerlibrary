@VERSION = __meteor_runtime_config__.VERSION

Template.registerHelper 'VERSION', ->
  @VERSION
