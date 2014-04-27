@createEditor = (template, $element, $toolbar, inline=false) ->
  scribe = new Scribe $element.get(0),
    allowBlockElements: not inline

  $element.on 'click', 'a', (event) =>
    # We have to prevent default so that our router is not triggered by a
    # click on a link while editing. External links are not active because
    # browsers disable them, but internal links we are processing ourselves
    # through our router (single page app) and have to make sure router
    # does not process them. Preventing default accomplishes that.
    event.preventDefault()
    return # Make sure CoffeeScript does not return anything

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
  scribe.use Scribe.plugins['keyboard-shortcuts'] commandsToKeyboardShortcutsMap
  scribe.use Scribe.plugins['link-prompt-command'](template)
  scribe.use Scribe.plugins['sanitizer']
    tags: tags
  scribe.use Scribe.plugins['toolbar'] $toolbar.get(0) if $toolbar

  template._$dialog = null

  scribe

@destroyEditor = (template) ->
  # Do we have to cleanup a dialog
  return unless template._$dialog

  $dialog = template._$dialog
  template._$dialog = null

  # We have to clean a dialog after current flush which
  # is just hapennig, otherwise Spark errors occur if
  # we remove DOM elements while Spark is working
  Deps.afterFlush ->
    $dialog.dialog('destroy')
