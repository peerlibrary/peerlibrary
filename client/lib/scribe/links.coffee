Scribe.plugins['link-prompt-command'] = ->
  (scribe) ->
    linkPromptCommand = new scribe.api.Command 'createLink'
    linkPromptCommand.nodeName = 'A'

    linkPromptCommand.execute = ->
      selection = new scribe.api.Selection()
      range = selection.range
      anchorNode = selection.getContaining (node) =>
        node.nodeName is @nodeName
      initialLink = (if anchorNode then anchorNode.href else "http://")
      link = window.prompt("Enter a link.", initialLink)

      if anchorNode
        range.selectNode anchorNode
        selection.selection.removeAllRanges range
        selection.selection.addRange range

      if link
        scribe.api.SimpleCommand::execute.call @, link

    linkPromptCommand.queryState = ->
      selection = new scribe.api.Selection()
      !!selection.getContaining (node) =>
        node.nodeName is @nodeName

    scribe.commands.linkPrompt = linkPromptCommand
