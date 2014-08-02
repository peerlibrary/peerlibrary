Handlebars.registerHelper 'keyboardShortcut', (options) ->
  if window?.navigator?.platform.toLowerCase().indexOf('mac') >= 0
    '⌘'
  else
    'Ctrl+'

START_TRIM_REGEX = />\s+/mg
END_TRIM_REGEX = /\s+</mg

Handlebars.registerHelper 'spaceless', (options) ->
  options.fn(@).replace(START_TRIM_REGEX, '>').replace(END_TRIM_REGEX, '<').trim()
