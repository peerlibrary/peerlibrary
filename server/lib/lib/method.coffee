@methodWrap = (f) ->
  (args...) ->
    try
      f.apply @, args
    catch error
      if error instanceof Error
        stack = StackTrace.printStackTrace e: error
        stack = if _.isArray stack then stack.join('\n') else stack
        if error instanceof Meteor.Error
          throw new Meteor.Error (error.error or 500), _.ensureSentence(error.reason or "Internal server error."), (error.details or "Stacktrace:\n#{ stack }")
        else
          throw new Meteor.Error 500, _.ensureSentence(error.message or "Internal server error."), "Stacktrace:\n#{ stack }"
      else
        throw new Meteor.Error 500, _.ensureSentence("#{ error }" or "Internal server error.")
