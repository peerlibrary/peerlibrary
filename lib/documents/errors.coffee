@LoggedErrors = new Meteor.Collection 'LoggedErrors', transform: (doc) => new @LoggedError doc

class @LoggedError extends Document
  # errorMsg: the error message
  # url: url that error ocurred on
  # lineNumber: line number in the code
  # userAgent: information about browser used, including version
  # windowWidth: width of window
  # windowHeight: height of window
  # screenWidth: width of screen
  # screenHeight: height of screen

  @Meta =>
    collection: LoggedErrors
