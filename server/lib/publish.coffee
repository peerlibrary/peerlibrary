unless originalPublish
  originalPublish = Meteor.publish

  Meteor.publish = (name, func) ->
    originalPublish name, (args...) ->
      person = Persons.findOne
        'user._id': @userId
      ,
        _id: 1

      @personId = person?._id or null

      func.apply @, args
