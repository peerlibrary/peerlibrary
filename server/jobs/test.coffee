class @TestJob extends Job
  run: ->
    console.log "Running test", @
    @log "Test log"

Job.addJobClass TestJob
