Scribe.plugins['link-prompt-command'] = ->
  (scribe) ->
    linkPromptCommand = new scribe.api.Command 'createLink'
    linkPromptCommand.nodeName = 'A'

    getParentAnchor = (selection) ->
      selection = new scribe.api.Selection() unless selection
      selection.getContaining (node) ->
        node.nodeName is linkPromptCommand.nodeName

    getChildAnchors = (selection) ->
      selection = new scribe.api.Selection() unless selection
      return [] unless selection.range

      range = new rangy.WrappedRange selection.range
      range.getNodes [1], (node) -> # 1 is element node type
        node.nodeName is linkPromptCommand.nodeName

    linkPromptCommand.execute = ->
      selection = new scribe.api.Selection()
      range = selection.range

      return unless range

      parentAnchor = getParentAnchor selection
      childAnchors = getChildAnchors selection

      currentEditor = $(range.commonAncestorContainer).closest('.content-editor')
      return unless currentEditor.length

      position =
        my: 'top+25'
        at: 'bottom'
        of: currentEditor
        collision: 'fit'

      buttons = []

      if childAnchors.length or parentAnchor
        buttons.push
          text: if childAnchors.length > 1 then "Remove links" else "Remove link"
          click: (event) =>
            if parentAnchor
              range.selectNode parentAnchor
              selection.selection.removeAllRanges()
              selection.selection.addRange range
              scribe.transactionManager.run =>
                new scribe.api.Element(parentAnchor.parentNode).unwrap(parentAnchor)

            else if childAnchors.length
              # TODO: Why unlink command here does not work here? (But this one does not work as well.)
              selection.selection.removeAllRanges()
              selection.selection.addRange range
              scribe.transactionManager.run =>
                for childAnchor in childAnchors
                  new scribe.api.Element(childAnchor.parentNode).unwrap(childAnchor)

            $dialog.dialog('destroy')

            return # Make sure CoffeeScript does not return anything

      buttons.push
        text: if parentAnchor then "Update" else "Create"
        click: (event) =>
          link = $dialog.find('.editor-link-input').val().trim()
          return unless link

          range.selectNode parentAnchor if parentAnchor
          selection.selection.removeAllRanges()
          selection.selection.addRange range

          scribe.api.SimpleCommand::execute.call @, link

          $dialog.dialog('destroy')

          return # Make sure CoffeeScript does not return anything

      $dialog = $(Template.editorLinkPrompt link: parentAnchor?.href).dialog
        dialogClass: 'editor-link-prompt-dialog'
        title: if parentAnchor then "Edit link" else "New link"
        position: position
        width: 300
        close: (event, ui) =>
          $dialog.remove()
          return # Make sure CoffeeScript does not return anything
        create: (event, ui) =>
          $(event.target).find('.editor-link-input').focus()
          return # Make sure CoffeeScript does not return anything
        buttons: buttons

    linkPromptCommand.queryState = ->
      # Is selection inside a link?
      return true if getParentAnchor()

      # Is link inside a selection?
      return !!getChildAnchors().length

    scribe.commands.linkPrompt = linkPromptCommand
