parentRead = MeteorFile::read

MeteorFile::read = (file, options, callback) ->
  if @collection.findOne(@_id)?.canceled
    return callback and callback 'canceled'
  return parentRead.apply @, arguments
