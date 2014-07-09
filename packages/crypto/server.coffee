crypto = Npm.require 'crypto'

Crypto =
  SHA256: class extends Crypto.SHA256
    constructor: (params) ->
      # params:
      #       onProgress -> progress callback function (optional)
      #                     arguments:
      #                             progress -> float, between 0 and 1 (inclusive)
      #       size -> complete file size (optional)
      @onProgress = params?.onProgress or ->
      @size = params?.size # this is unused
      @_hash = crypto.createHash 'sha256'

    update: (data, callback) =>
      # data -> Buffer (required)
      # callback -> callback function (optional)
      #     arguments:
      #             error -> Error instance or null if there is no error
      #             result -> Integer, 0 if everything is ok, -1 if not
      onDone = callback or ->
      error = null
      try
        @_hash.update data
      catch e
        error = e
      
      @onProgress 1
      onDone error, null

    finalize: (callback) =>
      # callback -> callback function (required)
      #     arguments:
      #             error -> Error instance or null if there is no error
      #             result -> Integer, 0 if everything is ok, -1 if not
      if not callback
        throw new Error 'callback not given!'
      error = null
      result = null
      try
        result = @_hash.digest 'hex'
      catch e
        error = e
      
      callback null, result

if Meteor.settings.secretKey
  Crypto.SECRET_KEY = Meteor.settings.secretKey
else
  Log.warn "Secret key setting missing, using public one"
  Crypto.SECRET_KEY = "She sang beyond the genius of the sea. The water never formed to mind or voice, Like a body wholly body, fluttering Its empty sleeves; and yet its mimic motion Made constant cry, caused constantly a cry, That was not ours although we understood, Inhuman, of the veritable ocean."
