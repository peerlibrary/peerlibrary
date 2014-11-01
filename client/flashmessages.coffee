positionFlashMessages = ($flashMessages, fast) ->
  top = 0
  $flashMessages.each (i, flashMessage) =>
    $flashMessage = $(flashMessage)
    $flashMessage.css
      top: top
      # Additionally, if we leave z-index constant for all flash messages
      # then because of the DOM order those later in the DOM are higher
      # than earlier. But we want the opposite so when flash message slides
      # (expands) down it goes over flash messages below.
      zIndex: $flashMessages.length - i
    if fast
      $flashMessage.addClass('fast-animate')
    else
      $flashMessage.removeClass('fast-animate')
    Tracker.afterFlush =>
      $flashMessage.addClass('animate')
    top += $flashMessage.outerHeight(true)

Template.flashMessagesOverlay.rendered = ->
  @autorun =>
    # A hacky way to get called every time flash messages rerender. This works
    # because there is a clear dependency (flashMessages) we have to use. It
    # would be much harder if we would have more complicated situation with
    # multiple dependencies.
    # TODO: Find a better way to get called every time flash messages rerender
    Template.flashMessagesOverlay.helpers('flashMessages')().fetch()

    # This currently is a hack because this should be rendered
    # as part of Meteor rendering, but it does not yet support
    # indexing. See https://github.com/meteor/meteor/pull/912
    # TODO: Reimplement using Meteor indexing of rendered elements (@index)
    positionFlashMessages @$('.flash-message'), false

Template.flashMessagesOverlay.helpers
  flashMessages: ->
    FlashMessage.documents.find {},
      sort:
        ['timestamp', 'asc']

Template.flashMessagesOverlayItem.created = ->
  @_timeout = null
  @_seen = false

Template.flashMessagesOverlayItem.rendered = ->
  # To simplify, we don't depend on data reactively, flash messages
  # do not really change once they are created. If we start changing
  # them (toggling stickiness, for example), then we have to make this
  # code reactive as well.

  return if @data.sticky

  $flashMessage = @$('.flash-message')

  @_timeout = new VisibleTimeout =>
    @_seen = true
    $flashMessage.fadeOut 'slow', =>
      FlashMessage.documents.remove @data._id
    @_timeout = null
  ,
    # Error messages are displayed longer
    if @data.type is 'error' then 10000 else 3000 # ms

  # Pause the timeout while user is hovering over the flashMessage
  $flashMessage.on 'mouseenter.flash-message', (event) =>
    @_timeout?.pause()
    return # Make sure CoffeeScript does not return anything

  $flashMessage.on 'mouseleave.flash-message', (event) =>
    @_timeout?.resume()
    return # Make sure CoffeeScript does not return anything

Template.flashMessagesOverlayItem.destroyed = ->
  @_timeout?.pause() if @_timeout
  @_timeout = null
  @_seen = false

Template.flashMessagesOverlayItem.events
  'click .button.icon-down': (event, template) ->
    event.preventDefault()

    Tracker.afterFlush =>
      template.$('.additional').slideDown
        # Twice as slow as CSS position transition animation time
        duration: 200
        step: (animation) =>
          positionFlashMessages $('.flash-messages .flash-message'), true
        complete: =>
          positionFlashMessages $('.flash-messages .flash-message'), false
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

Template.flashMessagesOverlayItem.helpers
  convertNewlines: (content) ->
    content.replace '\n', '<br/>' if content
