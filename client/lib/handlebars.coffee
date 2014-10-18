Template.registerHelper 'keyboardShortcut', ->
  if window?.navigator?.platform.toLowerCase().indexOf('mac') >= 0
    '⌘'
  else
    'Ctrl+'

Template.registerHelper 'json', (obj) ->
  JSON.stringify obj

Template.registerHelper 'collectionItemLink', ->
  href: @path unless @noLink
