Scribe.plugins['link-prompt-command'] = (template) ->
  (scribe) ->
    linkPromptCommand = new scribe.api.Command 'createLink'
    linkPromptCommand.nodeName = 'A'

    unlinkCommand = new scribe.api.Command 'unlink'

    getParentAnchor = (range) ->
      # First we find closest .content-editor or a, and then we keep only a if we found that
      $(range.commonAncestorContainer).closest(".content-editor, #{ linkPromptCommand.nodeName }").filter(linkPromptCommand.nodeName).get(0)

    getChildAnchors = (range) ->
      range.getNodes [1], (node) -> # 1 is element node type
        node.nodeName is linkPromptCommand.nodeName

    linkPromptCommand.execute = ->
      # This also restores any selection, so we should call it first.
      # We restore the selection so that if user double clicks on a link
      # button selection is not reset but stays on the link, for example.
      template._destroyDialog?()
      template._destroyDialog = null

      selection = rangy.getSelection()

      return unless selection.rangeCount
      range = selection.getRangeAt 0

      # TODO: Currently we support only one range per selection
      selection.setSingleRange range if selection.rangeCount > 1

      parentAnchor = getParentAnchor range
      childAnchors = getChildAnchors range
      collapsed = range.collapsed

      $currentEditor = $(range.commonAncestorContainer).closest('.content-editor')
      return unless $currentEditor.length

      savedSelection = rangy.saveSelection()

      # A simpler version to cleanup, until we have a dialog really open.
      # With this we also mark that dialog is in process of being created.
      template._destroyDialog = ->
        rangy.restoreSelection savedSelection, true

      # rangy.saveSelection adds marks to content, which triggers Scribe's mutation observers
      # which in turn mingles with focus when trying to manage changes to the content. So, to
      # leave time for mutation observers to run, we schedule the rest of the code onto the
      # event queue. This makes autofocusing the dialog input element (the one with autofocus
      # attribute) work again. Ugly, but it works.
      Meteor.defer =>
        position =
          my: 'top+25'
          at: 'bottom'
          of: $currentEditor
          collision: 'fit'

        updateLocation = ->
          if annotationId
            Meteor.Router.toNew Meteor.Router.annotationPath Session.get('currentPublicationId'), Session.get('currentPublicationSlug'), annotationId
          else
            # For local annotations, set location to the publication location
            Meteor.Router.toNew Meteor.Router.publicationPath Session.get('currentPublicationId'), Session.get('currentPublicationSlug')

        destroyDialog = ->
          $dialog.dialog('destroy')
          template._destroyDialog = null

          # Select parent annotation when closing the dialog
          updateLocation()

        selectParentAnchor = ->
          selection = rangy.getSelection()
          range = selection.getRangeAt 0
          # We have to find parent anchor again because original one might not be in DOM anymore
          parentAnchor = getParentAnchor range
          range.selectNode parentAnchor
          selection.setSingleRange range

        buttons = []

        if childAnchors.length or parentAnchor
          buttons.push
            text: if childAnchors.length > 1 then "Remove links" else "Remove link"
            class: 'alternative'
            click: (event) =>
              rangy.restoreSelection savedSelection, true

              # If we do not have a selection, but just a cursor
              # on an existing link, we unlink the whole link
              if collapsed and parentAnchor
                selectParentAnchor()

                # We store selection again so that we can reselect back exactly the same selection
                savedSelection = rangy.saveSelection()

                scribe.transactionManager.run =>
                  new scribe.api.Element(parentAnchor.parentNode).unwrap(parentAnchor)

                rangy.restoreSelection savedSelection, true

              else
                unlinkCommand.execute()

              destroyDialog()

              return # Make sure CoffeeScript does not return anything

        buttons.push
          text: if collapsed and parentAnchor then "Update" else "Create"
          class: 'default'
          click: (event) =>
            link = $dialog.find('.editor-link-input').val().trim()
            return unless link

            rangy.restoreSelection savedSelection, true

            # If we do not have a selection, but just a cursor on
            # an existing link, we replace whole link with a new one
            selectParentAnchor() if collapsed and parentAnchor

            scribe.api.SimpleCommand::execute.call @, link

            destroyDialog()

            return # Make sure CoffeeScript does not return anything

        # If for some reason we are not editing the annotation anymore, or are a comment editor, abort
        return unless template.data.editing or $currentEditor.hasClass 'comment-content-editor'

        editorLinkPrompt = Meteor.render =>
          Template.editorLinkPrompt
            link: parentAnchor?.href

        # To be able to destroy a dialog when template is destroyed. We
        # assign this to template before creating a dialog because we
        # are using template._destroyDialog to mark that dialog is open.
        # For example, we do not collapse a local editor if dialog is open.
        template._destroyDialog = ->
          # We do not call updateLocation or set template._destroyDialog
          # to null, all this should be done by our caller. We restore
          # the selection so that if user double clicks on a link button
          # selection is not reset but stays on the link, for example.
          rangy.restoreSelection savedSelection, true
          $dialog?.dialog('destroy')

        $dialog = $(editorLinkPrompt.childNodes).wrap('<div/>').parent().dialog
          dialogClass: 'editor-link-prompt-dialog'
          title: if collapsed and parentAnchor then "Edit link" else "New link"
          position: position
          width: 360
          close: (event, ui) =>
            rangy.restoreSelection savedSelection, true

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

    linkPromptCommand.queryState = ->
      selection = rangy.getSelection()

      return false unless selection.rangeCount
      range = selection.getRangeAt 0

      # Is selection inside a link?
      return true if getParentAnchor range

      # Is link inside a selection?
      return !!getChildAnchors(range).length

    scribe.commands.linkPrompt = linkPromptCommand
