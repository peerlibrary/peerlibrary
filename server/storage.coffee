class Storage extends Storage
  @_pdfPath: ->
    @_storageDirectory + @_path.sep + 'pdf'

  @_assurePath: (path) ->
    path = path.split @_path.sep
    for segment, i in path[1...path.length-1]
      p = path[0..i+1].join @_path.sep
      if !@_fs.existsSync p
        @_fs.mkdirSync p

  @save: (filename, data) ->
    filename = @_pdfPath() + @_path.sep + filename
    @_assurePath filename
    @_fs.writeFileSync filename, data

  @exists: (filename) ->
    @_fs.existsSync @_pdfPath() + @_path.sep + filename

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
