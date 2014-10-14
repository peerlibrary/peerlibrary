DEFAULT_JOB_TIMEOUT = 5 * 60 * 1000 # ms
STALLED_JOB_CHECK_INTERVAL = 60 * 1000 # ms
PROMOTE_INTERVAL = 15 * 1000 # ms

# We cannot directly extend Error type, because instanceof check
# does not work correctly, but we can use makeErrorType. Extending
# an error made with makeErrorType further works.
FatalJobError = Meteor.makeErrorType 'FatalJobError',
  (message) ->
    @message = message or ''

class @Job
  @types: {}
  @timeout: DEFAULT_JOB_TIMEOUT

  constructor: (@data) ->
    @data ||= {}

  run: =>
    throw new @constructor.FatalJobError "Not implemented"

  # Method so that job class can set or override enqueue options
  enqueueOptions: (options) =>
    options or {}

  enqueue: (options) =>
    throw new @constructor.FatalJobError "Unknown job class '#{ @type() }'" unless Job.types[@type()]

    # There is a race-condition here, but in the worst case there will be
    # some duplicate work done. Jobs ought to be idempotent anyway.
    return if options?.skipIfExisting and @constructor.exists @data, options?.skipIncludingCompleted

    job = JobQueue.Meta.collection.createJob @type(), @data

    options = @enqueueOptions options

    job.depends options.depends if options?.depends?
    job.priority options.priority if options?.priority?
    job.retry options.retry if options?.retry?
    job.repeat options.repeat if options?.repeat?
    job.delay options.delay if options?.delay?
    job.after options.after if options?.after?

    job.save options?.save

  # You should use .refresh() if you want full queue job document
  getQueueJob: =>
    JobQueue.Meta.collection.makeJob
      _id: @_id
      runId: @runId
      type: @type()
      data: @data

  log: (message, options, callback) =>
    @getQueueJob().log message, options, callback

  logInfo: (message, callback) =>
    @log message,
      level: 'info'
    ,
      callback

  logSuccess: (message, callback) =>
    @log message,
      level: 'success'
    ,
      callback

  logWarning: (message, callback) =>
    @log message,
      level: 'warning'
    ,
      callback

  logDanger: (message, callback) =>
    @log message,
      level: 'danger'
    ,
      callback

  progress: (completed, total, options, callback) =>
    @getQueueJob().progress completed, total, options, callback

  type: =>
    @constructor.type()

  @type: ->
    @name

  @addJobClass: (jobClass) ->
    throw new Error "Job class '#{ jobClass.name }' is not a subclass of Job class" unless jobClass.prototype instanceof Job
    throw new Error "Job class '#{ jobClass.type() }' already exists" if jobClass.type() of @types

    @types[jobClass.type()] = jobClass

  @FatalJobError: FatalJobError

  @exists: (data, includingCompleted) ->
    # Cancellable job statuses are in fact the same as those we want for existence check
    statuses = JobQueue.Meta.collection.jobStatusCancellable
    statuses = statuses.concat ['completed'] if includingCompleted

    values = (path, doc) ->
      res = {}
      for field, value of doc
        newPath = if path then "#{ path }.#{ field }" else field
        if _.isPlainObject value
          _.extend res, values newPath, value
        else
          res[newPath] = value
      res

    query = values '', data
    query.type = @type()
    query.status =
      $in: statuses

    JobQueue.documents.exists query

jobQueueRunning = false
runJobQueue = ->
  return if jobQueueRunning
  jobQueueRunning = true

  # We defer so that we can return quick so that observe keeps
  # running. We run here in a loop until there is no more work
  # when we go back to observe to wait for next ready job.
  Meteor.defer ->
    try
      loop
        try
          job = JobQueue.Meta.collection.getWork _.keys Job.types
          break unless job
        catch error
          # We retry if a race-condition was detected, there might still be jobs available
          continue if /Find after update failed|Missing running job/.test "#{ error }"
          throw error

        try
          try
            jobClass = Job.types[job.type]
            jobInstance = new jobClass job.data
            jobInstance._id = job._doc._id
            jobInstance.runId = job._doc.runId
            result = jobInstance.run()
          catch error
            if error instanceof Error
              stack = StackTrace.printStackTrace e: error
              job.fail EJSON.toJSONValue(value: error.message, stack: stack),
                fatal: error instanceof FatalJobError
            else
              job.fail EJSON.toJSONValue(value: "#{ error }")
            continue
          # TODO: Mark as ready all resolved dependent jobs
          job.done EJSON.toJSONValue result
        catch error
          Log.error "Error running a job queue: #{ error.stack or error }"
    finally
      jobQueueRunning = false

startJobs = ->
  JobQueue.Meta.collection.startJobs()

  Log.info "Worker enabled"

  # The query and sort here is based on the query in jobCollection's
  # getWork query. We want to have a query which is the same, just
  # that we observe with it and when there is any change, we call
  # getWork itself.
  JobQueue.documents.find(
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

WORKER_INSTANCES = parseInt(process.env.WORKER_INSTANCES || '1')
WORKER_INSTANCES = 1 unless _.isFinite WORKER_INSTANCES

@WORKER_INSTANCES = WORKER_INSTANCES

Meteor.startup ->
  # Worker is disabled
  return Log.info "Worker disabled" unless WORKER_INSTANCES

  # Check for promoted jobs at this interval. Jobs scheduled in the
  # future has to be made ready at regular intervals because time-based
  # queries are not reactive. time < NOW, NOW does not change as times go
  # on, once you make a query. More instances we have, less frequently
  # each particular instance should check.
  JobQueue.Meta.collection.promote WORKER_INSTANCES * PROMOTE_INTERVAL

  # We randomly delay start so that not all instances are promoting
  # at the same time, but dispersed over the whole interval.
  Meteor.setTimeout startJobs, Random.fraction() * WORKER_INSTANCES * PROMOTE_INTERVAL

  # Same deal with delaying and spreading the interval based on
  # the number of worker instances that we have for job promotion.
  Meteor.setTimeout ->
    Meteor.setInterval ->
      JobQueue.documents.find(status: 'running').forEach (jobQueueItem) ->
        try
          jobClass = Job.types[jobQueueItem.type]
          return if moment.utc().valueOf() < jobQueueItem.updated.valueOf() + jobClass.timeout

          job = JobQueue.Meta.collection.makeJob jobQueueItem
          job.log "No progress for more than #{ jobClass.timeout / 1000 } seconds",
            level: 'danger'
          job.cancel()
        catch error
          Log.error "Error while canceling a stalled job #{ jobQueueItem.type }/#{ jobQueueItem._id }: #{ error.stack or error }"
    , WORKER_INSTANCES * STALLED_JOB_CHECK_INTERVAL
  , Random.fraction() * WORKER_INSTANCES * STALLED_JOB_CHECK_INTERVAL

JobQueue.Meta.collection._ensureIndex
  type: 1
  status: 1

JobQueue.Meta.collection._ensureIndex
  priority: 1
  retryUntil: 1
  after: 1
