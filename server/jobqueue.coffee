class @JobQueue extends JobQueue
  @Meta
    name: 'JobQueue'
    replaceParent: true

  # A set of fields which are public and can be published to the client
  @PUBLISH_FIELDS: ->
    fields: {} # All, only admins have access

Meteor.publish 'job-queue', ->
  @related (person) ->
    return unless person?.isAdmin

    JobQueue.documents.find {}, JobQueue.PUBLISH_FIELDS()
  ,
    Person.documents.find
      _id: @personId
    ,
      fields:
        # _id field is implicitly added
        isAdmin: 1
