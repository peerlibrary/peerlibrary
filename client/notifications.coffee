# Local (client-only) collection with notifications
# Fields:
#   type: type of the notification (debug, warn, error)
#   timestamp: timestamp when was notification inserted
#   message: message of the notification
Notifications = new Meteor.Collection null

class @Notify
  @_insert: (type, message, additional) =>
    Notifications.insert
      type: type
      timestamp: moment.utc().toDate()
      message: message
      additional: additional

  @success: (message, additional) =>
    notificationId = @_insert 'success', message, additional

    if additional
      console.log message, additional
    else
      console.log message

    notificationId

  @debug: (message, additional) =>
    # For debugging we log only to the console
    if additional
      console.debug message, additional
    else
      console.debug message

    null

  @warn: (message, additional) =>
    notificationId = @_insert 'warn', message, additional

    if additional
      console.warn message, additional
    else
      console.warn message

    notificationId

  @meteorError: (error, log) =>
    @error error.reason, error.details, log

  @error: (message, additional, log, stack) =>
    additional = '' unless additional

    unless stack
      stack = new Error().stack
      # We skip first two lines as they are useless
      # (the first is "Error" and the second is location of this error function)
      stack = stack.split('\n')[2..].join('\n') if stack

    notificationAdditional = additional

    if stack
      notificationAdditional += "<div class=\"stack\">#{ _.escape(stack) }</div>"

    if log
      caller = Log._getCallerDetails(/client\/lib\/notifications(?:\/|(?::tests)?\.(?:js|coffee))/)

      loggedErrorId = @_logError [message, additional].join('\n'), caller.file, caller.line, stack

      notificationAdditional += "<div class=\"error-logged\">This error has been logged as #{ loggedErrorId }.</div>"

    notificationId = @_insert 'error', message, notificationAdditional

    if loggedErrorId
      logged = "<logged as #{ loggedErrorId }>"
    else
      logged = '<not logged>'

    if additional
      console.error message, additional, logged, stack
    else
      console.error message, logged, stack

    notificationId

  @_logError: (errorMsg, url, lineNumber, stack) =>
    session = {}
    for key, value of Session.keys
      # Dots are forbidden in MongoDB fields
      key = key.replace /\./g, ' '
      # Values are EJSON encoded, let's decode them
      session[key] = EJSON.parse(value)

    LoggedErrors.insert
      errorMsg: errorMsg
      url: url
      lineNumber: lineNumber
      stack: stack
      location: document.location.toString()
      userAgent: navigator.userAgent
      language: navigator.language
      doNotTrack: (navigator.msDoNotTrack or navigator.doNotTrack) in ["1", "yes", "true", 1, true]
      clientTime: moment.utc().toDate()
      windowWidth: window.innerWidth
      windowHeight: window.innerHeight
      screenWidth: screen.width
      screenHeight: screen.height
      session: session
      status: Meteor.status()
      protocol: Meteor.connection?._stream?.socket?.protocol
      settings: Meteor.settings
      release: Meteor.release
      version: VERSION
      PDFJS: _.pick PDFJS, 'maxImageSize', 'disableFontFace', 'disableWorker', 'disableRange', 'disableAutoFetch', 'pdfBug', 'postMessageTransfers', 'disableCreateObjectURL', 'verbosity'

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
  Notifications.find {},
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
      Notifications.remove @data._id
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
    if $(e.target).hasClass('icon-down-open')
      e.preventDefault()

      Deps.afterFlush =>
        $(template.findAll '.additional').slideDown
          # Twice as slow as CSS position transition animation time
          duration: 200
          step: (animation) =>
            positionNotifications $('.notifications .notification'), true
          complete: =>
            positionNotifications $('.notifications .notification'), false
            $(e.target).addClass('icon-close').removeClass('icon-down-open').attr('title', 'Close')

    else if $(e.target).hasClass('icon-close')
      Notifications.remove @_id unless e.isDefaultPrevented()

    return # Make sure CoffeeScript does not return anything

  'click': (e, template) ->
    Notifications.remove @_id unless e.isDefaultPrevented() or $(template.findAll '.button').hasClass('icon-close')

    return # Make sure CoffeeScript does not return anything

Template.notificationsOverlayItem.additional = ->
  # We allow additional information to be raw HTML content,
  # but we make sure that it can be plain text as well
  @additional.replace '\n', '<br/>' if @additional
