#Store the original functionality of read as a variable.
parentRead = MeteorFile::read

MeteorFile::read = (file, options, callback) ->
  #Modify the read function. Disallow reading to continue if import canceled.
  #If it's not been canceled, carry on with original functionality.
  if @collection.findOne(@_id)?.canceled
    return callback and callback 'canceled'

  return parentRead.apply @, arguments
