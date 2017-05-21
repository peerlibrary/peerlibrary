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
  result = Meteor.execFileSync 'git', ['describe', '--always', '--dirty=+']

  gitversion = result.stdout.split('\n')[0] if result.success

gitversion = 'error' unless gitversion

__meteor_runtime_config__.VERSION = @VERSION = gitversion
