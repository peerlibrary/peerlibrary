parentRead = MeteorFile::read

MeteorFile::read = (file, options, callback) ->
  if @collection.findOne(@_id)?.canceled
    return callback and callback 'canceled'
  args = arguments
  setTimeout =>
    return parentRead.apply @, args
  , 500
  return

