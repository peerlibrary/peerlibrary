# Here we override jobCollection's Job class with something completely different.
# We are not using => but -> so that it is easy to serialize job's payload and
# that it is not combined with instance methods made by =>.
class @Job
  @types = {}

  constructor: (data) ->
    _.extend @, data

  run: ->
    throw new Error "Not implemented"

  # Method so that job class can set or override enqueue options
  enqueueOptions: (options) ->
    options

  enqueue: (options) ->
    # We use EJSON.toJSONValue to convert to an object with only fields and no methods
    job = JobQueue.Meta.collection.createJob @type(), EJSON.toJSONValue @

    options = @enqueueOptions options

    job.depends options.depends if options?.depends?
    job.priority options.priority if options?.priority?
    job.retry options.retry if options?.retry?
    job.repeat options.repeat if options?.repeat?
    job.delay options.delay if options?.delay?
    job.after options.after if options?.after?

    job.save options

  # You should use .refresh() if you want full queue job document
  getQueueJob: ->
    JobQueue.Meta.collection.makeJob
      _id: @_id
      runId: @_runId
      type: @type()
      data: {}

  log: (message, options) ->
    @getQueueJob().log message, options

  progress: (completed, total, options) ->
    @getQueueJob().progress completed, total, options

  type: ->
    @constructor.type()

  @type: ->
    @name

  @addJobClass: (jobClass) ->
    throw new Error "Job class '#{ jobClass.name }' is not a subclass of Job class" unless jobClass.prototype instanceof Job
    throw new Error "Job class '#{ jobClass.type() }' already exists" if jobClass.type() of @types

    @types[jobClass.type()] = jobClass

jobQueueRunning = false
runJobQueue = ->
  return if jobQueueRunning
  jobQueueRunning = true

  # We defer so that we can return quick so that observe keeps
  # running. We run here in a loop until there is no more work
  # when we go back to observe to wait for next ready job.
  Meteor.defer ->
    try
      while job = JobQueue.Meta.collection.getWork _.keys Job.types
        try
          try
            j = new Job.types[job.type](job.data)
            j._id = job._doc._id
            j._runId = job._doc.runId
            result = j.run()
          catch error
            job.fail EJSON.toJSONValue error.stack or error.toString?() or error
            continue
          job.done EJSON.toJSONValue result
        catch error
          Log.error "Error running a job queue: #{ error.stack or error.toString?() or error }"
    finally
      jobQueueRunning = false

Meteor.startup ->
  # TODO: Allow configuration to run only on workers
  # TODO: Set promote interval based on number of workers
  JobQueue.Meta.collection.startJobs()
  Log.info "Worker enabled"

  JobQueue.Meta.collection.find(
    status: 'ready'
    runId: null
  ,
    sort:
      priority: 1
      retryUntil: 1
      after: 1
    fields:
      _id: 1
  ).observe
    added: (document) ->
      runJobQueue()

    changed: (newDocument, oldDocument) ->
      runJobQueue()

JobQueue.Meta.collection._ensureIndex
  type: 1
  status: 1
