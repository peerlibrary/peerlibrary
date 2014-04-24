oldOnError = window.onerror
window.onerror = (errorMsg, url, lineNumber) ->
  Notify._logError errorMsg, url, lineNumber, null

  if oldOnError
    oldOnError errorMsg, url, lineNumber
  else
    false
