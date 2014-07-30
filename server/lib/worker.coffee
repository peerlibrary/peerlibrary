IGNORED_PROPERTIES = [
  'constructor'
  'allow'
  'deny'
  'find'
  'findOne'
  'insert'
  'update'
  'remove'
  'upsert'
]

# We copy JobCollection public methods to JobQueue document for easy access
for propertyName, propertyValue of JobQueue.Meta.collection.constructor.prototype
  do (propertyName, propertyValue) ->
    if _.isFunction(propertyValue) and not _.startsWith(propertyName, '_') and propertyName not in IGNORED_PROPERTIES
      JobQueue[propertyName] = (args...) ->
        @Meta.collection[propertyName].apply @Meta.collection, args

# Here we override jobCollection's Job class. We are not using => but -> so
# that it is easy to serialize job's payload and that it is not combined
# with instance methods made by =>.
class @Job
  @types = {}

  constructor: (data) ->
    _.extend @, data

  run: ->
    throw new Error "Not implemented"

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

  while job = JobQueue.getWork _.keys Job.types
    new Job.types[job.type](job.data).run()
    job.done()

  queueRunning = false

Meteor.startup ->
  # TODO: Use Meteor's logging package for logging
  JobQueue.setLogStream process.stdout
  # TODO: Allow configuration to run only on workers
  # TODO: Set promote interval based on number of workers
  JobQueue.startJobs()
  Log.info "Worker enabled"

  # TODO: Remove
  JobQueue.Meta.collection.allow
    admin: (userId, method, params) ->
      true

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
