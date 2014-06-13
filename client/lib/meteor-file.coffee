# Store the original MeteorFile's read method
parentRead = MeteorFile::read

MeteorFile::read = (file, options, callback) ->
  # Modify the read method. Disallow reading to continue if import is canceled.
  return callback 'canceled' if @collection.findOne(@_id)?.canceled

  Meteor.setTimeout ->

    return parentRead.apply @, arguments

  , 30000