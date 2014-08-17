class @JobQueue extends JobQueue
  @Meta
    name: 'JobQueue'
    replaceParent: true

  # A set of fields which are public and can be published to the client
  @PUBLISH_FIELDS: ->
    # All, only admins have access, but we limit to last 10 entries in the log (it can grow quite big)
    fields:
      log:
        $slice: -10

Meteor.publish 'job-queue', ->
  @related (person) ->
    return unless person?.isAdmin

    JobQueue.documents.find {},
      fields: JobQueue.PUBLISH_FIELDS().fields
      limit: 30
  ,
    Person.documents.find
      _id: @personId
    ,
      fields:
        # _id field is implicitly added
        isAdmin: 1
