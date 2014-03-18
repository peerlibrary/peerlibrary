unless originalPublish
  originalPublish = Meteor.publish

  Meteor.publish = (name, func) ->
    originalPublish name, (args...) ->
      # Not the pretiest code in existence, we are redoing the query for each publish call.
      # It would be much better if we could rerun this only when userId is invalidated and
      # store personId in the current method invocation context and then just retrieve it
      # here.
      # TODO: Optimize this code
      person = Person.documents.findOne
        'user._id': @userId
      ,
        _id: 1
        inGroups: 1

      @personId = person?._id or null
      @personGroups = _.pluck person?.inGroups, '_id'

      func.apply @, args
