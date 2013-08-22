fs = Npm.require 'fs'
path = Npm.require 'path'

class Storage extends @Storage
  @_assurePath: (path) ->
    path = path.split @_path.sep
    for segment, i in path[1...path.length-1]
      p = path[0..i+1].join @_path.sep
      if !fs.existsSync p
        fs.mkdirSync p

  @save: (filename, data) ->
    filename = @_storageDirectory + @_path.sep + filename
    @_assurePath filename
    fs.writeFileSync filename, data

  @exists: (filename) ->
    fs.existsSync @_storageDirectory + @_path.sep + filename

  @open: (filename) ->
    fs.readFileSync @_storageDirectory + @_path.sep + filename

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

@Storage = Storage
