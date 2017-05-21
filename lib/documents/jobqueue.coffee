if Meteor.isServer
  class @JobCollection extends JobCollection
    scrub: (job) ->
      # We have to make a plain object (our documents go through PeerDB transform)
      # and without _schema field which is added to all PeerDB documents
      _.omit job, '_schema', 'constructor'

    _toLog: (userId, method, message) =>
      Log.info "#{ method }: #{ message }"

# Document is wrapping jobCollection collection so additional fields might be
# added by future versions of the package. An actual schema can be found in
# validJobDoc function, see
# https://github.com/vsivsi/meteor-job-collection/blob/master/shared.coffee#L50
# Fields listed below are partially documented, mostly those which we are using
# elsewhere around our code.
class @JobQueue extends Document
  # runId: ID of the current run
  # type: one of Job class names
  # status: status of the job
  # data: arbitrary object with data for the job
  #   publication: optional reference to the publication this job is associated with
  # result: arbitrary object with result
  # failures: information about job failures
  # priority: priority, lower is higher
  # depends: list of job dependencies
  # resolved: list of resolved job dependencies
  # after: should run after this time
  # updated: was updated at this time
  # log: list of log entries
  #   time
  #   runId
  #   level
  #   message
  # progress:
  #   completed
  #   total
  #   percent
  # retries
  # retried
  # retryUntil
  # retryWait
  # retryBackoff
  # repeats
  # repeated
  # repeatUntil
  # repeatWait
  # created

  @Meta
    name: 'JobQueue'

    collection: new JobCollection 'JobQueue',
      noCollectionSuffix: true

    fields: =>
      # Data can be arbitrary object, but we have one field which we can use
      # if job is referencing a publication. This is then used to allow
      # publications to link back to related jobs.
      data:
        publication: @ReferenceField Publication, [], false, 'jobs', ['status']

  @verboseName: ->
    'job'
