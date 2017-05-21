Meteor.execFileSync = (file, args, opts) ->
  Future = Npm.require 'fibers/future'
  child_process = Npm.require 'child_process'
  future = new Future()

  child_process.execFile file, args, opts, (error, stdout, stderr) ->
    future.return
      success: not error
      stdout: stdout
      stderr: stderr

  future.wait()
