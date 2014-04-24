(($) ->
  $.fn.editable = (isEditableFunction, updateFunction, placeholderText) ->
    throw new Error "Editable only works on a single element" if @length > 1
    $editableButton = null
    $editView = null
    $element = @
    editableText = $element.text().trim()

    hideView = ->
      # Restore the content with initial elements
      $element.show()
      $editView.remove()
      $editView = null

      return # Make sure CoffeeScript does not return anything

    return Deps.autorun ->
      # Editable class determines if we've already initialized this element
      return unless isEditableFunction()

      # Prepare the editable button
      $editableButton = $(Template.editableButton null)
      $editableButton.click (e) ->
        # Create the edit form
        $editView = $(Template.editable null)

        $editInput = $editView.find('.editable-input')
        $editInput.attr('value', editableText) unless $element.hasClass('missing-value')
        $editInput.attr('placeholder', placeholderText) if placeholderText

        $editCancel = $editView.find('.editable-cancel')
        $editCancel.click(hideView)

        $editView.submit (e) ->
          e.preventDefault()

          value = $editInput.val()
          updateFunction value

          hideView()

          return # Make sure CoffeeScript does not return anything

        # Replace the content with the edit form
        $element.after($editView)
        $element.hide()

        # Focus on the input
        $editInput.focus()

      # Add the editable button
      $element.append($editableButton).addClass('editable')

      # Clean after self
      Deps.onInvalidate ->
        hideView() if $editView
        $editableButton.remove()
        $editableButton = null

)(jQuery)