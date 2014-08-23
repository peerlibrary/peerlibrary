positionNotifications = ($notifications, fast) ->
  top = 0
  $notifications.each (i, notification) =>
    $notification = $(notification)
    $notification.css
      top: top
      # Additionally, if we leave z-index constant for all notifications
      # then because of the DOM order those later in the DOM are higher
      # than earlier. But we want the opposite so when notification slides
      # (expands) down it goes over notifications below.
      zIndex: $notifications.length - i
    if fast
      $notification.addClass('fast-animate')
    else
      $notification.removeClass('fast-animate')
    Deps.afterFlush =>
      $notification.addClass('animate')
    top += $notification.outerHeight(true)

Template.notificationsOverlay.rendered = ->
  # This currently is a hack because this should be rendered
  # as part of Meteor rendering, but it does not yet support
  # indexing. See https://github.com/meteor/meteor/pull/912
  # TODO: Reimplement using Meteor indexing of rendered elements (@index)
  positionNotifications $(@findAll '.notification'), false

Template.notificationsOverlay.notifications = ->
  Notify.documents.find {},
    sort:
      ['timestamp', 'asc']

Template.notificationsOverlayItem.created = ->
  @_timeout = null
  @_seen = false

Template.notificationsOverlayItem.rendered = ->
  return if @_timeout or @_seen

  $notification = $(@findAll '.notification')

  return if @data.sticky

  @_timeout = new VisibleTimeout =>
    @_seen = true
    $notification.fadeOut 'slow', =>
      Notify.documents.remove @data._id
    @_timeout = null
  ,
    # Error messages are displayed longer
    if @data.type is 'error' then 10000 else 3000 # ms

  # Pause the timeout while user is hovering over the notification
  $notification.on 'mouseenter.notification', (event) =>
    @_timeout.pause() if @_timeout
    return # Make sure CoffeeScript does not return anything
  $notification.on 'mouseleave.notification', (event) =>
    @_timeout.resume() if @_timeout
    return # Make sure CoffeeScript does not return anything

Template.notificationsOverlayItem.destroyed = ->
  if @_timeout
    Meteor.clearTimeout @_timeout
    @_timeout = null
  @_seen = false

Template.notificationsOverlayItem.events
  'click .button': (event, template) ->
    if $(event.target).hasClass('icon-down')
      event.preventDefault()

      Deps.afterFlush =>
        $(template.findAll '.additional').slideDown
          # Twice as slow as CSS position transition animation time
          duration: 200
          step: (animation) =>
            positionNotifications $('.notifications .notification'), true
          complete: =>
            positionNotifications $('.notifications .notification'), false
            $(event.target).addClass('icon-cancel').removeClass('icon-down').attr('title', 'Cancel')

    else if $(event.target).hasClass('icon-cancel')
      Notify.documents.remove @_id unless event.isDefaultPrevented()

    return # Make sure CoffeeScript does not return anything

  'click .stack': (event, template) ->
    event.preventDefault()

    $('.stack').select()

    return

  'click': (event, template) ->
    Notify.documents.remove @_id unless event.isDefaultPrevented() or $(template.findAll '.button').hasClass('icon-cancel')

    return # Make sure CoffeeScript does not return anything

Template.notificationsOverlayItem.additional = ->
  # We allow additional information to be raw HTML content,
  # but we make sure that it can be plain text as well
  @additional.replace '\n', '<br/>' if @additional
