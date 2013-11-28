oldOnError = window.onerror
window.onerror = (errorMsg, url, lineNumber) ->
  Errors.insert
    errorMsg: errorMsg
    url: url
    lineNumber: lineNumber
    userAgent: navigator.userAgent
    windowWidth: window.innerWidth
    windowHeight: window.innerHeight
    screenWidth: screen.width
    screenHeight: screen.height

  if oldOnError
    oldOnError errorMsg, url, lineNumber
  else
    false