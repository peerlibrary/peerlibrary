Storage =
  url: (filename) ->
    '/pdf/' + filename

  save: (filename, data) ->
    path = @_storageDirectory + @_path.sep + 'pdf'
    if !@_fs.existsSync path
      @_fs.mkdirSync path
    @_fs.writeFileSync path + @_path.sep + filename, data

do -> # To not pollute the namespace
  require = __meteor_bootstrap__.require

  assert = require 'assert'
  fs = require 'fs'
  path = require 'path'

  # Find .meteor directory
  directoryPath = process.mainModule.filename.split path.sep
  while directoryPath.length > 0
    directory = directoryPath.pop()
    if directory == '.meteor'
      break

  assert directoryPath.length > 0

  directoryPath.push 'public'
  Storage._storageDirectory = directoryPath.join path.sep
  Storage._fs = fs
  Storage._path = path
