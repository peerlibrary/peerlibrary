class @TestJob extends Job
  run: ->
    @log "Test log"

Job.addJobClass TestJob
