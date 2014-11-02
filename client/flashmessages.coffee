Template.flashMessagesOverlay.helpers
  flashMessages: ->
    FlashMessage.documents.find
      stickyHidden:
        $ne: true
    ,
      sort: [
        ['timestamp', 'asc']
      ]

Template.flashMessagesOverlayItem.created = ->
  @_timeout = null

Template.flashMessagesOverlayItem.rendered = ->
  # To simplify, we don't depend on data reactively, flash messages
  # do not really change once they are created. If we start changing
  # them (toggling stickiness, for example), then we have to make this
  # code reactive as well.

  return if @data.sticky

  @_timeout = new VisibleTimeout =>
    @$('.flash-message').velocity 'fadeOut',
      duration: 'slow'
      queue: false
      # We just want to hide the element and not remove it.
      display: null
      visibility: 'hidden'
      complete: =>
        # And now we remove it.
        FlashMessage.documents.remove @data._id
    @_timeout = null
  ,
    # Error messages are displayed longer
    if @data.type is 'error' then 10000 else 3000 # ms

Template.flashMessagesOverlayItem.destroyed = ->
  @_timeout?.pause() if @_timeout
  @_timeout = null

Template.flashMessagesOverlayItem.events
  'click .button.icon-down': (event, template) ->
    event.preventDefault()

    Tracker.afterFlush =>
      template.$('.additional').velocity 'slideDown',
        duration: 'fast'
        complete: =>
          $(event.target).addClass('icon-cancel').removeClass('icon-down').attr('title', 'Cancel')

    return # Make sure CoffeeScript does not return anything

  'click .button.icon-cancel': (event, template) ->
    return if event.isDefaultPrevented()

    if @sticky
      FlashMessage.documents.update @_id,
        $set:
          stickyHidden: true
    else
      FlashMessage.documents.remove @_id

    return # Make sure CoffeeScript does not return anything

  'click .stack': (event, template) ->
    event.preventDefault()

    $('.stack').select()

    return

  'click': (event, template) ->
    return if event.isDefaultPrevented() or template.$('.button').hasClass('icon-cancel')

    if @sticky
      FlashMessage.documents.update @_id,
        $set:
          stickyHidden: true
    else
      FlashMessage.documents.remove @_id

    return # Make sure CoffeeScript does not return anything

  # Pause the timeout while user is hovering over the flashMessage.

  'mouseenter .flash-message': (event, template) ->
    template._timeout?.pause()
    return # Make sure CoffeeScript does not return anything

  'mouseleave .flash-message': (event, template) ->
    template._timeout?.resume()
    return # Make sure CoffeeScript does not return anything

Template.flashMessagesOverlayItem.helpers
  convertNewlines: (content) ->
    content.replace '\n', '<br/>' if content
