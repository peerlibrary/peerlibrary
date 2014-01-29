@LoggedErrors = new Meteor.Collection 'LoggedErrors', transform: (doc) => new @LoggedError doc

class @LoggedError extends Document
  # errorMsg: the error message
  # url: url that error ocurred on
  # lineNumber: line number in the code where error occured on
  # location: document location (URL) as seen by JavaScript at the moment of the error
  # userAgent: browser information string
  # language: language set in the browser (not language from HTTP headers)
  # doNotTrack: does user request not to be tracked (we do not link error to the user in this case)
  # clientTime: client time in the browser when the error occured (in UTC)
  # windowWidth: width of user's window
  # windowHeight: height of user's window
  # screenWidth: width of user's screen
  # screenHeight: height of user's screen
  # session: Meteor session state when the error occured
  # status: status of Meteor connection to the server
  # protocol: protocol of the connection to the server (websocket, xhr-polling, etc.)
  # settings: Meteor settings, if used at this instance
  # release: Meteor release, if not custom release/fork
  # version: version of PeerLibrary running on the client
  # PDFJS:
  #   maxImageSize: maxImageSize PDF.js setting
  #   disableFontFace: disableFontFace PDF.js setting
  #   disableWorker: disableWorker PDF.js setting
  #   disableRange: disableRange PDF.js setting
  #   disableAutoFetch: disableAutoFetch PDF.js setting
  #   pdfBug: pdfBug PDF.js setting
  #   postMessageTransfers: postMessageTransfers PDF.js setting
  #   disableCreateObjectURL: disableCreateObjectURL PDF.js setting
  #   verbosity: verbosity PDF.js setting
  # serverTime: server time when the error was received (in UTC)
  # parsedUserAgent: parsed and more structured information about user's browser
  # person: if user was logged in and has not opted-out, reference to the person for whom the error occured, otherwise null
  #   _id: person's id

  @Meta =>
    collection: LoggedErrors
    fields:
      # Person reference is not required (user can opt-out)
      person: @ReferenceField Person, [], false
