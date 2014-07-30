# Here we override jobCollection's Job class. We are not using => but -> so
# that it is easy to serialize job's payload and that it is not combined
# with instance methods made by =>.
class @Job
  @types = {}

  constructor: (data) ->
    _.extend @, data

  run: ->
    throw new Error "Not implemented"

  enqueue: (options) ->
    job = JobQueue.Meta.collection.createJob @type(), EJSON.toJSONValue @

    # TODO: Process options

    job.save()

  type: ->
    @constructor.type()

  @type: ->
    @name

  @addJobClass: (jobClass) ->
    throw new Error "Job class '#{ jobClass.name }' is not a subclass of Job class" unless jobClass.prototype instanceof Job
    throw new Error "Job class '#{ jobClass.type() }' already exists" if jobClass.type() of @types

    @types[jobClass.type()] = jobClass

queueRunning = false
jobQueue = ->
  return if queueRunning
  queueRunning = true

  while job = JobQueue.Meta.collection.getWork _.keys Job.types
    try
      result = new Job.types[job.type](job.data).run()
    catch error
      job.fail error
      continue
    job.done result

  queueRunning = false

Meteor.startup ->
  # TODO: Use Meteor's logging package for logging
  JobQueue.Meta.collection.setLogStream process.stdout
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
      jobQueue()

    changed: (newDocument, oldDocument) ->
      jobQueue()

JobQueue.Meta.collection._ensureIndex
  type: 1
  status: 1
