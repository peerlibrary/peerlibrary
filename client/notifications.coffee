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

  @_timeout = new VisibleTimeout =>
    @_seen = true
    $notification.fadeOut 'slow', =>
      Notify.documents.remove @data._id
    @_timeout = null
  ,
    7000 # ms

  # Pause the timeout while user is hovering over the notification
  $notification.on 'mouseenter.notification', (e) =>
    @_timeout.pause() if @_timeout
    return # Make sure CoffeeScript does not return anything
  $notification.on 'mouseleave.notification', (e) =>
    @_timeout.resume() if @_timeout
    return # Make sure CoffeeScript does not return anything

Template.notificationsOverlayItem.destroyed = ->
  if @_timeout
    Meteor.clearTimeout @_timeout
    @_timeout = null
  @_seen = false

Template.notificationsOverlayItem.events
  'click .button': (e, template) ->
    if $(e.target).hasClass('icon-down')
      e.preventDefault()

      Deps.afterFlush =>
        $(template.findAll '.additional').slideDown
          # Twice as slow as CSS position transition animation time
          duration: 200
          step: (animation) =>
            positionNotifications $('.notifications .notification'), true
          complete: =>
            positionNotifications $('.notifications .notification'), false
            $(e.target).addClass('icon-cancel').removeClass('icon-down').attr('title', 'Cancel')

    else if $(e.target).hasClass('icon-cancel')
      Notify.documents.remove @_id unless e.isDefaultPrevented()

    return # Make sure CoffeeScript does not return anything

  'click .stack': (e, template) ->
    e.preventDefault()

    $('.stack').select()

    return

  'click': (e, template) ->
    Notify.documents.remove @_id unless e.isDefaultPrevented() or $(template.findAll '.button').hasClass('icon-cancel')

    return # Make sure CoffeeScript does not return anything

Template.notificationsOverlayItem.additional = ->
  # We allow additional information to be raw HTML content,
  # but we make sure that it can be plain text as well
  @additional.replace '\n', '<br/>' if @additional
