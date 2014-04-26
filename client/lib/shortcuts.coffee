Handlebars.registerHelper 'keyboardShortcut', ->
  if window?.navigator?.platform.toLowerCase().indexOf('mac') >= 0
    '⌘'
  else
    'Ctrl+'
