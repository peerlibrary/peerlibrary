# Updates the lastActivity field when any of provided
# fields of a document change
class LastActivityTriggerClass extends Document._Trigger
  updateLastActivity: (id, timestamp) =>
    @document.documents.update
      _id: id
      $or: [
        lastActivity:
          $lt: timestamp
      ,
        lastActivity: null
      ]
    ,
      $set:
        lastActivity: timestamp

  constructor: (fields, trigger) ->
    super fields, trigger or (newDocument, oldDocument) ->
      # Don't do anything when document is removed
      return unless newDocument?._id

      # Don't do anything if there was no change
      return if _.isEqual newDocument, oldDocument

      timestamp = moment.utc().toDate()
      @updateLastActivity newDocument._id, timestamp

@LastActivityTrigger = (args...) ->
  new LastActivityTriggerClass args...

# Updates the lastActivity field of a related document when
# any of provided fields of a document change
class RelatedLastActivityTriggerClass extends Document._Trigger
  updateLastActivity: (id, timestamp) =>
    @relatedDocument.documents.update
      _id: id
      $or: [
        lastActivity:
          $lt: timestamp
      ,
        lastActivity: null
      ]
    ,
      $set:
        lastActivity: timestamp

  constructor: (@relatedDocument, fields, @relatedIds) ->
    super fields, (newDocument, oldDocument) ->
      # Don't do anything when document is removed
      return unless newDocument?._id

      # Don't do anything if there was no change
      return if _.isEqual newDocument, oldDocument

      timestamp = moment.utc().toDate()
      relatedIds = @relatedIds newDocument, oldDocument
      relatedIds = [relatedIds] unless _.isArray relatedIds
      for relatedId in relatedIds when relatedId
        @updateLastActivity relatedId, timestamp

@RelatedLastActivityTrigger = (args...) ->
  new RelatedLastActivityTriggerClass args...

# When any content fields (provided fields) of a document
# change we update both updatedAt and lastActivity fields
class UpdatedAtTriggerClass extends LastActivityTriggerClass
  updateUpdatedAt: (id, timestamp) =>
    @document.documents.update
      _id: id
      $or: [
        updatedAt:
          $lt: timestamp
      ,
        updatedAt: null
      ]
    ,
      $set:
        updatedAt: timestamp

  constructor: (fields, noLastActivity) ->
    super fields, (newDocument, oldDocument) ->
      # Don't do anything when document is removed
      return unless newDocument?._id

      # Don't do anything if there was no change
      return if _.isEqual newDocument, oldDocument

      timestamp = moment.utc().toDate()
      @updateUpdatedAt newDocument._id, timestamp

      # Every time we update updatedAt, we update lastActivity as well
      @updateLastActivity newDocument._id, timestamp unless noLastActivity

@UpdatedAtTrigger = (args...) ->
  new UpdatedAtTriggerClass args...
