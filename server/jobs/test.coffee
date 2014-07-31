class @TestJob extends Job
  run: =>
    @log "Test log"

    # Return @foo value
    @foo

Job.addJobClass TestJob
