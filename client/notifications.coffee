# Local (client-only) collection with notifications
# Fields:
#   type: type of the notification (debug, warn, error)
#   timestamp: timestamp when was notification inserted
#   message: message of the notification
Notifications = new Meteor.Collection null

class @Notification
  @success: (message) =>
    notificationId = Notifications.insert
      type: 'success'
      timestamp: moment.utc().toDate()
      message: message

    console.log message

    notificationId

  @debug: (message) =>
    notificationId = Notifications.insert
      type: 'warn'
      timestamp: moment.utc().toDate()
      message: message

    console.debug message

    notificationId

  @warn: (message) =>
    notificationId = Notifications.insert
      type: 'warn'
      timestamp: moment.utc().toDate()
      message: message

    console.warn message

    notificationId

  @error: (message, log, stack) =>
    notificationId = Notifications.insert
      type: 'error'
      timestamp: moment.utc().toDate()
      message: message

    console.error message

    caller = Log._getCallerDetails(/client\/lib\/notifications(?:\/|(?::tests)?\.(?:js|coffee))/)
    unless stack
      stack = new Error().stack
      # We skip first two lines as they are useless
      # (the first is "Error" and the second is location of this error function)
      stack = stack.split('\n')[2..].join('\n') if stack

    @_logError message, caller.file, caller.line, stack

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

Template.notificationsOverlay.rendered = ->
  # This currently is a hack because this should be rendered
  # as part of Meteor rendering, but it does not yet support
  # indexing. See https://github.com/meteor/meteor/pull/912
  # TODO: Reimplement using Meteor indexing of rendered elements (@index)
  top = 0
  $notifications = $(@findAll '.notification')
  $notifications.each (i, notification) =>
    $(notification).css
      top: top
    Deps.afterFlush ->
      $(notification).addClass('animate')
    top += $(notification).height()

Template.notificationsOverlay.notifications = ->
  Notifications.find {},
    sort:
      ['timestamp', 'asc']

Template.notificationsOverlayItem.created = ->
  @_timeout = null
  @_seen = false

Template.notificationsOverlayItem.rendered = ->
  return if @_timeout or @_seen

  @_timeout = Meteor.setTimeout =>
    @_seen = true
    $(@findAll '.notification').fadeOut 'slow', =>
      Notifications.remove @data._id
    @_timeout = null
  ,
    10000 # ms

Template.notificationsOverlayItem.destroyed = ->
  if @_timeout
    Meteor.clearTimeout @_timeout
    @_timeout = null
    @_seen = false

Template.notificationsOverlayItem.events
  'click': (e, template) ->
    Notifications.remove @_id

    return # Make sure CoffeeScript does not return anything
