unless originalPublish
  originalPublish = Meteor.publish

  Meteor.publish = (name, func) ->
    originalPublish name, (args...) ->
      publish = @

      # Not the prettiest code in existence, we are redoing the query for each publish call.
      # It would be much better if we could rerun this only when userId is invalidated and
      # store personId in the current method invocation context and then just retrieve it
      # here.
      # TODO: Optimize this code
      if @userId
        person = Person.documents.findOne
          'user._id': @userId
        ,
          _id: 1

      publish.personId = person?._id or null

      # TODO: Modify publish._recreate so that it copies personId

      func.apply publish, args
