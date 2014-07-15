# Local (client-only) document for notifications
class @Notify extends BaseDocument
  # type: type of the notification (debug, warn, error)
  # timestamp: timestamp when was notification inserted
  # message: message of the notification

  @Meta
    name: 'Notify'
    collection: null

  @_insert: (type, message, additional) =>
    @documents.insert
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

    stack = StackTrace.printStackTrace() unless stack

    notificationAdditional = additional

    if stack
      displayStack = if _.isArray stack then stack.join('\n') else stack
      notificationAdditional += "<textarea class=\"stack\" name=\"stack\" rows=\"10\" cols=\"30\">#{ _.escape(displayStack) }</textarea>"

    afterLogging = (error, loggedErrorId) =>
      # Ignoring error

      notificationAdditional += "<div class=\"error-logged\">This error has been logged as #{ loggedErrorId }.</div>" if loggedErrorId

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

    if log
      caller = StackTrace.getCaller()
      match = caller.match /@(.*\/.+\.(?:coffee|js).*?)(?::(\d+))?(?::(\d+))?$/ if caller
      @_logError [message, additional].join('\n'), (match?[1] or null), (match?[2] or match?[3] or null), stack, afterLogging
    else
      afterLogging null, null

  @_logError: (errorMsg, url, lineNumber, stack, callback) =>
    session = {}
    for key, value of Session.keys
      # Dots are forbidden in MongoDB fields
      key = key.replace /\./g, ' '
      # Values are EJSON encoded, let's decode them
      session[key] = EJSON.parse(value)

    Meteor.call 'log-error',
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
    ,
      callback or ->
