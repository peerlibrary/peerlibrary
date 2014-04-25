@createEditor = ($element, $toolbar, inline=false) ->
  scribe = new Scribe $element.get(0),
    allowBlockElements: not inline

  # For inline editor block elements and no <br/>
  tags =
    b: {}
    i: {}
    a:
      href: true

  unless inline
    tags = _.extend tags,
      p: {}
      br: {}
      blockquote: {}
      ol: {}
      ul: {}
      li: {}
      h4: {} # TODO: We need a toolbar icon for this

  commandsToKeyboardShortcutsMap =
    bold: (event) -> (event.metaKey or event.ctrlKey) && event.keyCode is 66 # b
    italic: (event) -> (event.metaKey or event.ctrlKey) && event.keyCode is 73 # i
    removeFormat: (event) -> (event.metaKey or event.ctrlKey) && event.keyCode is 75 # k
    linkPrompt: (event) -> (event.metaKey or event.ctrlKey) && event.keyCode is 76 # l

  scribe.use Scribe.plugins['blockquote-command']()
  scribe.use Scribe.plugins['heading-command'](4) # Heading should be h4
  scribe.use Scribe.plugins['intelligent-unlink-command']()
  scribe.use Scribe.plugins['keyboard-shortcuts'] commandsToKeyboardShortcutsMap
  scribe.use Scribe.plugins['link-prompt-command']()
  scribe.use Scribe.plugins['sanitizer']
    tags: tags
  scribe.use Scribe.plugins['toolbar'] $toolbar.get(0) if $toolbar

  scribe
