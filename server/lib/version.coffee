Future = Npm.require 'fibers/future'
child_process = Npm.require 'child_process'

execFileSync = (file, args, opts) ->
  future = new Future

  child_process.execFile file, args, opts, (err, stdout, stderr) ->
    future.return
      success: not err
      stdout: stdout
      stderr: stderr

  future.wait()

result = execFileSync 'git', ['describe', '--always', '--dirty=+']

__meteor_runtime_config__.VERSION = if result.success then (result.stdout.split('\n')[0] or 'error') else 'error'

console.log __meteor_runtime_config__.VERSION