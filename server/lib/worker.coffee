FatalJobError = Meteor.makeErrorType 'FatalJobError',
  (message) ->
    @message = message or ''

class @Job
  @types = {}

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

    # We use EJSON.toJSONValue to convert to an object with only fields and no methods
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
      while job = JobQueue.Meta.collection.getWork _.keys Job.types
        try
          try
            jobClass = Job.types[job.type]
            j = new jobClass job.data
            j._id = job._doc._id
            j.runId = job._doc.runId
            result = j.run()
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
          Log.error "Error running a job queue: #{ error.stack or error.toString?() or error }"
    finally
      jobQueueRunning = false

Meteor.startup ->
  # TODO: Allow configuration to run only on workers
  # TODO: Set promote interval based on number of workers
  JobQueue.Meta.collection.startJobs()
  Log.info "Worker enabled"

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

JobQueue.Meta.collection._ensureIndex
  type: 1
  status: 1
