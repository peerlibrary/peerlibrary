# Local (client-only) document for notifications
class @Notify extends Document
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

    unless stack
      stack = new Error().stack
      # We skip first two lines as they are useless
      # (the first is "Error" and the second is location of this error function)
      stack = stack.split('\n')[2..].join('\n') if stack

    notificationAdditional = additional

    if stack
      notificationAdditional += "<textarea class=\"stack\" name=\"stack\" rows=\"10\" cols=\"30\">#{ _.escape(stack) }</textarea>"

    if log
      # TODO: Should we use instead PeerDB's getCurrentLocation?
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
