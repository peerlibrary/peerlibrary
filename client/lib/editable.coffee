(($) ->
  $.fn.editable = (isEditableFunction, updateFunction, placeholderText, resizeToContent) ->
    throw new Error "Editable only works on a single element" if @length > 1
    $editableButton = null
    $editView = null
    $element = @
    editableText = $element.text().trim()
    $elementContents = null

    hideView = ->
      # Restore the content with initial elements
      $editView.remove()
      $editView = null
      $element.append($elementContents).removeClass('editing')

      return # Make sure CoffeeScript does not return anything

    return Deps.autorun ->
      # Editable class determines if we've already initialized this element
      return unless isEditableFunction()

      # Prepare the editable button
      $editableButton = $(Template.editableButton null)
      $editableButton.click (e) ->
        # Create the edit form
        $editView = $(Template.editable null)

        if resizeToContent
          $wrap = $element.wrapInner('<span/>').children()
          $editView.css('width', $wrap.get(0).getBoundingClientRect().width)
          $wrap.contents().appendTo($wrap.parent())
          $wrap.remove()

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
        $elementContents = $element.contents().detach()
        $element.append($editView).addClass('editing')

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

# Helper that enables template to be editable
class @Editable
  @template: (template, isEditableFunction, updateFunction, placeholderText, resizeToContent) ->
    # Make sure we don't override template callbacks
    assert not template.created
    assert not template.rendered
    assert not template.destroyed

    template.created = ->
      @_editable = null

    template.rendered = ->
      @_editable.stop() if @_editable
      console.log @firstNode
      @_editable = $(@findAll '> *').editable(isEditableFunction.bind(@), updateFunction.bind(@), placeholderText, resizeToContent)

    template.destroyed = ->
      @_editable.stop() if @_editable
      @_editable = null