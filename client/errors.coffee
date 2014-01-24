oldOnError = window.onerror
window.onerror = (errorMsg, url, lineNumber) ->
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

  if oldOnError
    oldOnError errorMsg, url, lineNumber
  else
    false