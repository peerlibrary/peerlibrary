class TestJob extends Job
  run: ->
    console.log "Running test", @

Job.addJobClass TestJob
