Fiber = Npm.require 'fibers'
fs = Npm.require 'fs'
pathModule = Npm.require 'path'
url = Npm.require 'url'

NON_ASCII_REGEX = /[^\040-\176]/
CACHE_ID_REGEX = new RegExp "^/([#{ UNMISTAKABLE_CHARS }]{17})\\.(\\w+)$"

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

  @saveStreamAsync: (filename, stream, callback) ->
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

  @saveStream: (filename, stream) ->
    blocking(@, @saveStreamAsync) filename, stream

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

if process.env.STORAGE_DIRECTORY
  Storage._storageDirectory = process.env.STORAGE_DIRECTORY
else
  # Find .meteor directory
  directoryPath = process.mainModule.filename.split pathModule.sep
  while directoryPath.length > 0
    if directoryPath[directoryPath.length - 1] == '.meteor'
      break
    directoryPath.pop()

  assert directoryPath.length > 0

  directoryPath.push 'storage'
  Storage._storageDirectory = directoryPath.join pathModule.sep

Storage._path = pathModule

# Taken from express utils.js
contentDisposition = (filename) ->
  return 'attachment' unless filename

  filename = pathModule.basename filename

  # If filename contains non-ASCII characters, add a UTF-8 version ala RFC 5987
  if NON_ASCII_REGEX.test filename
    return "attachment; filename=\"#{ encodeURI filename }\"; filename*=UTF-8''#{ encodeURI filename }"
  else
    return "attachment; filename=\"#{ filename }\""

setHeader = (req, res, next, filename) ->
  res.setHeader 'Content-Disposition', contentDisposition filename
  next()

WebApp.connectHandlers.use '/storage/publication/cache', (req, res, next) ->
  fiber = Fiber ->
    parsedUrl = url.parse req.url
    filename = parsedUrl.pathname
    match = CACHE_ID_REGEX.exec filename

    return setHeader req, res, next, filename unless match

    cachedId = match[1]
    extension = match[2]
    publication = Publication.documents.findOne
      cachedId: cachedId
    ,
      fields:
        title: 1

    filename = "#{ publication.title }.#{ extension }" if publication?.title

    return setHeader req, res, next, filename

  fiber.run()

# TODO: What about security? If ../.. are passed in?
# TODO: Currently, if there is no file, processing is passed further and Meteor return 200 content, we should return 404 for this files
# TODO: Add CORS headers
# TODO: We have redirect == false because directory redirects do not take prefix into the account
WebApp.connectHandlers.use '/storage', connect.static(Storage._storageDirectory, {maxAge: 24 * 60 * 60 * 1000, redirect: false})
WebApp.connectHandlers.use '/storage', (req, res, next) ->
  res.statusCode = 404
  # TODO: Use our own 404 content, matching the 404 shown by nginx
  res.end '404 Not Found', 'utf8'
