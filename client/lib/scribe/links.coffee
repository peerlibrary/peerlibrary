Scribe.plugins['link-prompt-command'] = (template) ->
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

      template._$dialog.dialog('destroy') if template._$dialog
      template._$dialog = null

      position =
        my: 'top+25'
        at: 'bottom'
        of: currentEditor
        collision: 'fit'

      updateLocation = ->
        if annotationId
          Meteor.Router.toNew Meteor.Router.annotationPath Session.get('currentPublicationId'), Session.get('currentPublicationSlug'), annotationId
        else
          # For local annotations, set location to the publication location
          Meteor.Router.toNew Meteor.Router.publicationPath Session.get('currentPublicationId'), Session.get('currentPublicationSlug')

      destroyDialog = ->
        $dialog.dialog('destroy')
        template._$dialog = null

        # Select parent annotation when closing the dialog
        updateLocation()

      buttons = []

      if childAnchors.length or parentAnchor
        buttons.push
          text: if childAnchors.length > 1 then "Remove links" else "Remove link"
          class: 'alternative'
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

            destroyDialog()

            return # Make sure CoffeeScript does not return anything

      buttons.push
        text: if parentAnchor then "Update" else "Create"
        class: 'default'
        click: (event) =>
          link = $dialog.find('.editor-link-input').val().trim()
          return unless link

          range.selectNode parentAnchor if parentAnchor
          selection.selection.removeAllRanges()
          selection.selection.addRange range

          scribe.api.SimpleCommand::execute.call @, link

          destroyDialog()

          return # Make sure CoffeeScript does not return anything

      editorLinkPrompt = Meteor.render =>
        Template.editorLinkPrompt
          link: parentAnchor?.href

      $dialog = $(editorLinkPrompt.childNodes).wrap('<div/>').parent().dialog
        dialogClass: 'editor-link-prompt-dialog'
        title: if parentAnchor then "Edit link" else "New link"
        position: position
        width: 360
        close: (event, ui) =>
          range.selectNode parentAnchor if parentAnchor
          selection.selection.removeAllRanges()
          selection.selection.addRange range

          destroyDialog()

          return # Make sure CoffeeScript does not return anything
        buttons: buttons

      if template.data instanceof Comment
        annotationId = template.data.annotation._id
      else if template.data instanceof Annotation
        # We do not want to change location for local annotations
        annotationId = template.data._id unless template.data.local
      else
        assert false

      $dialogWrapper = $dialog.closest('.editor-link-prompt-dialog')

      # We use mouseup and not click so that draging
      # a dialog around updates location, too
      $dialogWrapper.on 'mouseup', (event) =>
        # Select parent annotation on click on the dialog
        updateLocation()

        return # Make sure CoffeeScript does not return anything

      # We also have to manually do hover events again, because dialog is
      # not part of the annotation so event handlers there do not apply.
      # In general we have to duplicate all event handlers used for UX.
      # We have to duplicate event handlers because we cannot just move
      # dialogs inside the annotation DOM element because then it cannot
      # be dragged around the page freely, but it is clipped by the
      # annotation list.

      $dialogWrapper.on 'mouseenter', (e) =>
        $('.viewer .display-wrapper .highlights-layer .highlights-layer-highlight').trigger 'annotationMouseenter', [annotationId] if annotationId
        return # Make sure CoffeeScript does not return anything

      $dialogWrapper.on 'mouseleave', (e, highlightId) =>
        $('.viewer .display-wrapper .highlights-layer .highlights-layer-highlight').trigger 'annotationMouseleave', [annotationId] if annotationId
        return # Make sure CoffeeScript does not return anything

      # To be able to destroy a dialog when template is destroyed
      template._$dialog = $dialog

    linkPromptCommand.queryState = ->
      # Is selection inside a link?
      return true if getParentAnchor()

      # Is link inside a selection?
      return !!getChildAnchors().length

    scribe.commands.linkPrompt = linkPromptCommand
