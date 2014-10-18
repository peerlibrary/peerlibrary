@VERSION = __meteor_runtime_config__.VERSION

Handlebars.registerHelper 'VERSION', ->
  @VERSION
