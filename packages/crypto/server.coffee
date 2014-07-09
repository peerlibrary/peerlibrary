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
