crypto = Npm.require 'crypto'

Crypto =
  SHA256: class extends Crypto.SHA256
    constructor: (params) ->
      super
      @_total = 0
      @_hash = crypto.createHash 'sha256'

    update: (data, callback) =>
      callback ?= ->

      try
        @_hash.update data
        @_total += data.length
      catch error
        return callback error

      if @size?
        @onProgress @_total / @size
      else
        @onProgress()

      callback null

    finalize: (callback) =>
      callback ?= ->

      try
        sha256 = @_hash.digest 'hex'
      catch error
        return callback error

      callback null, sha256
      sha256
