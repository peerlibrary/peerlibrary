class LastChangedTimestampTriggerClass extends Document._Trigger
  constructor: (fields) ->
    if Meteor.isClient
      super fields
    else
      super fields, (newDocument, oldDocument) ->
        # Don't do anything when document is removed
        return unless newDocument._id

        timestamp = moment.utc().toDate()
        @document.documents.update
          _id: newDocument._id
          updatedAt:
            $lt: timestamp
        ,
          $set:
            updatedAt: timestamp

@LastChangedTimestampTrigger = (args...) ->
  new LastChangedTimestampTriggerClass args...
