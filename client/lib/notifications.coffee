# As an exception we are using fat arrow (=>) for class methods here so that methods can be easily
# passed as callbacks, but extending the class and overriding class methods might not work as you expect.
# If class method A calls bound class method B, even if you override B with B' in a subclass, when
# calling A on a subclass, it will still call B and not B'.

# Local (client-only) document for notifications
class @Notify extends BaseDocument
  # type: type of the notification (debug, warn, error)
  # timestamp: timestamp when was notification inserted
  # message: message of the notification
  # additional: additional data of the notification
  # sticky: if true (can be any custom value useful for identifying the
  #         notification) notification is not removed automatically

  @Meta
    name: 'Notify'
    collection: null

  @_insert: (type, message, additional, sticky) =>
    @documents.insert
      type: type
      timestamp: moment.utc().toDate()
      message: message
      additional: additional
      sticky: sticky

  @success: (message, additional, sticky) =>
    notificationId = @_insert 'success', message, additional, sticky

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

  @warn: (message, additional, sticky) =>
    notificationId = @_insert 'warn', message, additional, sticky

    if additional
      console.warn message, additional
    else
      console.warn message

    notificationId

  @fromError: (error, log) =>
    if error instanceof Meteor.Error
      if _.startsWith error.details, 'Stacktrace:\n'
        @error _.ensureSentence(error.reason), null, log, error.details.substring('Stacktrace:\n'.length)
      else
        @error _.ensureSentence(error.reason), error.details, log
    else if error instanceof Error
      stack = StackTrace.printStackTrace e: error
      stack = if _.isArray stack then stack.join('\n') else stack
      @error _.ensureSentence(error.message or error.stringOf?() or "Unknown error."), null, log, stack
    else
      @error _.ensureSentence("#{ error }"), null, log

  # If stack is false then it is not automatically added
  @error: (message, additional, log, stack, sticky) =>
    additional = '' unless additional

    stack = StackTrace.printStackTrace() unless stack or stack is false

    notificationAdditional = additional

    if stack
      displayStack = if _.isArray stack then stack.join('\n') else stack
      notificationAdditional += "<textarea class=\"stack\" name=\"stack\" rows=\"10\" cols=\"30\">#{ _.escape(displayStack).replace(/\n/g, '&#10;') }</textarea>"

    afterLogging = (error, loggedErrorId) =>
      # Ignoring error

      notificationAdditional += "<div class=\"error-logged\">This error has been logged as #{ loggedErrorId }.</div>" if loggedErrorId

      notificationId = @_insert 'error', message, notificationAdditional, sticky

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
      location: "#{ document.location }"
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
