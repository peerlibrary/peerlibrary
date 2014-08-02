class @TestJob extends Job
  enqueueOptions: (options) =>
    options = super

    _.defaults options,
      priority: 'low'

  run: =>
    @logInfo "Test log"

    # Return @foo value
    @foo

Job.addJobClass TestJob
