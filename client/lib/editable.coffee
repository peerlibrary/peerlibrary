hideEditView = (template) ->
  return unless template._editView

  # Restore the content with initial elements.
  Blaze.remove template._editView
  template._editView = null

  template._$element.append(template._$elementContents).removeClass('editing')
  template._$elementContents = null

Template.editable.rendered = ->
  baseTemplate = @parent 2

  @$('.editable-control').css('width', baseTemplate._$elementWidth) if baseTemplate._$elementWidth and baseTemplate._resizeToContent

  $editInput = @$('.editable-input')
  $editInput.attr('value', baseTemplate._$elementContents.text().trim()) unless baseTemplate._$element.hasClass('missing-value')
  $editInput.attr('placeholder', baseTemplate._placeholderText) if baseTemplate._placeholderText

  # Focus on the input
  Meteor.setTimeout =>
    $editInput.focus()
  , 10 # ms

Template.editable.events
  'submit form': (event, template) ->
    event.preventDefault()

    baseTemplate = template.parent 2

    baseTemplate._update template.$('.editable-input').val()

    hideEditView baseTemplate

    return # Make sure CoffeeScript does not return anything

  'click .editable-cancel': (event, template) ->
    hideEditView template.parent 2

    return # Make sure CoffeeScript does not return anything

Template.editableButton.events
  'click button': (event, template) ->
    baseTemplate = template.parent 1
    # Replace the content with the edit form.
    baseTemplate._$elementWidth = baseTemplate._$element.contentsWidth()
    baseTemplate._$elementContents = baseTemplate._$element.contents().detach()
    baseTemplate._editView = Blaze.render Template.editable, baseTemplate._$element.get(0), null, template.view
    baseTemplate._$element.addClass('editing')

    return # Make sure CoffeeScript does not return anything

(($) ->

  $.fn.editable = (template) ->
    throw new Error "Editable only works on a single element" if @length > 1

    template._$element = @
    renderedButton = null

    template.autorun ->
      return unless template._isEditable()

      renderedButton = Blaze.render Template.editableButton, template._$element.get(0), null, template.view
      template._$element.addClass('editable')

      Tracker.onInvalidate ->
        hideEditView template
        Blaze.remove renderedButton if renderedButton
        renderedButton = null

)(jQuery)

# Helper that enables a template to be editable
class @Editable
  @template: (template, isEditable, update, placeholderText, resizeToContent) ->
    # Make sure we don't override template callbacks.
    assert not template.created
    assert not template.rendered
    assert not template.destroyed

    template.created = ->
      @_isEditable = _.bind isEditable, @
      @_update = _.bind update, @
      @_placeholderText = placeholderText
      @_resizeToContent = resizeToContent
      @_$element = null
      @_$elementWidth = null
      @_$elementContents = null
      @_editView = null

    template.rendered = ->
      @$('> *').editable @

    template.destroyed = ->
      @_isEditable = null
      @_update = null
      @_placeholderText = null
      @_resizeToContent = null
      @_$element = null
      @_$elementWidth = null
      @_$elementContents = null
      @_editView = null
