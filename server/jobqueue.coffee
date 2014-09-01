class @JobQueue extends JobQueue
  @Meta
    name: 'JobQueue'
    replaceParent: true

  # A set of fields which are public and can be published to the client
  @PUBLISH_FIELDS: ->
    fields: {} # All

Meteor.methods
  'admin-job-cancel': methodWrap (jobId, runId) ->
    validateArgument 'jobId', jobId, DocumentId
    validateArgument 'runId', runId, OptionalOrNull DocumentId

    runId = null unless runId

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    job = JobQueue.Meta.collection.getJob jobId
    throw new Meteor.Error 400, "Invalid job." unless job and job._doc.runId is runId

    if job.data.publication
      publication = job.data.publication.refresh Publication.maintainerAccessSelfFields()
      throw new Meteor.Error 403, "Permission denied." unless publication.hasMaintainerAccess person
      job.cancel()
    else if person.isAdmin
      job.cancel()
    else
      throw new Meteor.Error 403, "Permission denied."

  'admin-job-restart': methodWrap (jobId, runId) ->
    validateArgument 'jobId', jobId, DocumentId
    validateArgument 'runId', runId, OptionalOrNull DocumentId

    runId = null unless runId

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    job = JobQueue.Meta.collection.getJob jobId
    throw new Meteor.Error 400, "Invalid job." unless job and job._doc.runId is runId

    if person.isAdmin
      job.restart()
    else if job.data.publication
      publication = job.data.publication.refresh Publication.maintainerAccessSelfFields()
      throw new Meteor.Error 403, "Permission denied." unless publication.hasMaintainerAccess person
      job.restart()
    else
      throw new Meteor.Error 403, "Permission denied."

Meteor.publish 'job-queue', ->
  @related (person) ->
    return unless person?.isAdmin

    JobQueue.documents.find {},
      fields: _.extend JobQueue.PUBLISH_FIELDS().fields,
        # We limit to the last 10 entries in the log (it can grow quite big)
        log:
          $slice: -10
      # And to the 30 most recently updated jobs in the queue
      limit: 30
      sort: [
        ['updated', 'desc']
      ]
  ,
    Person.documents.find
      _id: @personId
    ,
      fields:
        # _id field is implicitly added
        isAdmin: 1

Meteor.publish 'jobs-by-publication', (publicationId) ->
  validateArgument 'publicationId', publicationId, DocumentId

  @related (person, publication) ->
    return unless publication?.hasReadAccess person

    JobQueue.documents.find
      'data.publication._id': publication._id
    , JobQueue.PUBLISH_FIELDS()
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: Publication.readAccessPersonFields()
  ,
    Publication.documents.find
      _id: publicationId
    ,
      fields: Publication.readAccessSelfFields()

JobQueue.Meta.collection._ensureIndex
  updated: -1
