Storage =
  url: (filename) ->
    '/pdf/' + filename

  _pdfPath: ->
    @_storageDirectory + @_path.sep + 'pdf'

  save: (filename, data) ->
    path = @_pdfPath()
    if !@_fs.existsSync path
      @_fs.mkdirSync path
    # TODO: For some reason if file is saved, fiber is restarted, clients reconnects and whole process is restarted and then it succeds because file is already downloaded
    @_fs.writeFileSync path + @_path.sep + filename, data

  open: (filename) ->
    @_fs.readFileSync @_pdfPath() + @_path.sep + filename

do -> # To not pollute the namespace
  require = __meteor_bootstrap__.require

  assert = require 'assert'
  fs = require 'fs'
  future = require 'fibers/future'
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
  Storage._future = future
  Storage._path = path
