fs = Npm.require 'fs'
path = Npm.require 'path'

class @Storage extends Storage
  @_assurePath: (path) ->
    path = path.split @_path.sep
    for segment, i in path[1...path.length-1]
      p = path[0..i+1].join @_path.sep
      if !fs.existsSync p
        fs.mkdirSync p

  @_assurePathAsync: (path, callback) ->
    path = path.split @_path.sep
    i = 0
    async.eachSeries path[1...path.length-1], (segment, callback) =>
      i++
      p = path[0..i].join @_path.sep
      fs.exists p, (exists) =>
        return callback null if exists
        fs.mkdir p, callback
    ,
      callback

  @_fullPath: (filename) ->
    assert filename
    @_storageDirectory + @_path.sep + filename

  @save: (filename, data) ->
    path = @_fullPath filename
    @_assurePath path
    fs.writeFileSync path, data

  @saveStream: (filename, stream, callback) ->
    stream.pause()

    path = @_fullPath filename
    @_assurePathAsync path, (error) ->
      return callback error if error

      finished = false
      stream.on('error', (error) ->
        return if finished
        finished = true
        callback error
      ).pipe(
        fs.createWriteStream path
      ).on('finish', ->
        return if finished
        finished = true
        callback null
      ).on('error', (error) ->
        return if finished
        finished = true
        callback error
      )

      stream.resume()

  @saveMeteorFile: (meteorFile, filename) ->
    path = @_fullPath filename
    directory = path.split('/').slice(0, -1).join('/')
    meteorFile.name = filename.split('/').slice(-1)[0]
    @_assurePath path
    meteorFile.save directory, {}

  @exists: (filename) ->
    fs.existsSync @_fullPath filename

  @open: (filename) ->
    fs.readFileSync @_fullPath filename

  @rename: (oldFilename, newFilename) ->
    newPath = @_fullPath newFilename
    @_assurePath newPath
    fs.renameSync @_fullPath(oldFilename), newPath

  @link: (existingFilename, newFilename) ->
    newPath = @_fullPath newFilename
    @_assurePath newPath
    existingPath = @_fullPath existingFilename
    fs.symlinkSync @_path.relative(@_path.dirname(newPath), existingPath), newPath

  @remove: (filename) ->
    fs.unlinkSync @_fullPath filename

  @lastModificationTime: (filename) ->
    stats = fs.statSync @_fullPath filename
    stats.mtime

# Find .meteor directory
directoryPath = process.mainModule.filename.split path.sep
while directoryPath.length > 0
  if directoryPath[directoryPath.length - 1] == '.meteor'
    break
  directoryPath.pop()

assert directoryPath.length > 0

directoryPath.push 'storage'
Storage._storageDirectory = directoryPath.join path.sep
Storage._path = path

# TODO: What about security? If ../.. are passed in?
# TODO: Currently, if there is no file, processing is passed further and Meteor return 200 content, we should return 404 for this files
# TODO: Add CORS headers
# TODO: We have redirect == false because directory redirects do not take prefix into the account
WebApp.connectHandlers.use('/storage', connect.static(Storage._storageDirectory, {maxAge: 24 * 60 * 60 * 1000, redirect: false}))
