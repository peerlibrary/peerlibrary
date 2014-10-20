(($) ->

  $.fn.editable = (isEditableFunction, updateFunction, placeholderText, resizeToContent) ->
    throw new Error "Editable only works on a single element" if @length > 1
    $editableButton = null
    $editView = null
    $element = @
    $elementContents = null

    hideView = ->
      # Restore the content with initial elements
      $editView.remove()
      $editView = null
      $element.append($elementContents).removeClass('editing')

      return # Make sure CoffeeScript does not return anything

    return Tracker.autorun ->
      # Editable class determines if we've already initialized this element
      return unless isEditableFunction()

      # Prepare the editable button
      $editableButton = $(Blaze.toHTML Template.editableButton)
      $editableButton.click (event) ->
        # Create the edit form
        $editView = $(Blaze.toHTML Template.editable)

        $editView.css('width', $element.contentsWidth()) if resizeToContent

        $editInput = $editView.find('.editable-input')
        $editInput.attr('value', $element.text().trim()) unless $element.hasClass('missing-value')
        $editInput.attr('placeholder', placeholderText) if placeholderText

        $editCancel = $editView.find('.editable-cancel')
        $editCancel.click(hideView)

        $editView.submit (event) ->
          event.preventDefault()

          value = $editInput.val()
          updateFunction value

          hideView()

          return # Make sure CoffeeScript does not return anything

        # Replace the content with the edit form
        $elementContents = $element.contents().detach()
        $element.append($editView).addClass('editing')

        # Focus on the input
        Meteor.setTimeout =>
          $editInput.focus()
        , 10 # ms

      # Add the editable button
      $element.append($editableButton).addClass('editable')

      # Clean after self
      Tracker.onInvalidate ->
        hideView() if $editView
        $editableButton.remove()
        $editableButton = null

)(jQuery)

# Helper that enables a template to be editable
class @Editable
  @template: (template, isEditableFunction, updateFunction, placeholderText, resizeToContent) ->
    # Make sure we don't override template callbacks
    assert not template.created
    assert not template.rendered
    assert not template.destroyed

    template.created = ->
      @_editable = null

    template.rendered = ->
      @_editable = @$('> *').editable(isEditableFunction.bind(@), updateFunction.bind(@), placeholderText, resizeToContent)

    template.destroyed = ->
      @_editable?.stop()
      @_editable = null
