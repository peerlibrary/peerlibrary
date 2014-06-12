class UpdatedAtFieldClass extends Document._GeneratedField
  constructor: (targetDocument, fields) ->
    if Meteor.isClient
      super targetDocument, fields
    else
      super targetDocument, fields, (fields) ->
        [fields._id, moment.utc().toDate()]

@UpdatedAtField = (args...) ->
  new UpdatedAtFieldClass args...
