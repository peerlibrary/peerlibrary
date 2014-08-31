fs = Npm.require 'fs'
path = Npm.require 'path'

gitversion = null

try
  gitversionFile = fs.readFileSync "#{ path.dirname(process.mainModule.filename) }#{ path.sep }gitversion",
    encoding: 'utf8'
  gitversion = gitversionFile.split('\n')[0]
catch error
  gitversion = null

unless gitversion
  Future = Npm.require 'fibers/future'
  child_process = Npm.require 'child_process'

  execFileSync = (file, args, opts) ->
    future = new Future()

    child_process.execFile file, args, opts, (error, stdout, stderr) ->
      future.return
        success: not error
        stdout: stdout
        stderr: stderr

    future.wait()

  result = execFileSync 'git', ['describe', '--always', '--dirty=+']

  gitversion = result.stdout.split('\n')[0] if result.success

gitversion = 'error' unless gitversion

__meteor_runtime_config__.VERSION = @VERSION = gitversion
