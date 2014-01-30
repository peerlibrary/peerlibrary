oldOnError = window.onerror
window.onerror = (errorMsg, url, lineNumber) ->
  Notification._logError errorMsg, url, lineNumber

  if oldOnError
    oldOnError errorMsg, url, lineNumber
  else
    false
