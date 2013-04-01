class Storage extends Storage
  @_pdfPath: ->
    @_storageDirectory + @_path.sep + 'pdf'

  @save: (filename, data) ->
    path = @_pdfPath()
    if !@_fs.existsSync path
      @_fs.mkdirSync path
    @_fs.writeFileSync path + @_path.sep + filename, data

  @open: (filename) ->
    @_fs.readFileSync @_pdfPath() + @_path.sep + filename

do -> # To not pollute the namespace
  require = __meteor_bootstrap__.require

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
