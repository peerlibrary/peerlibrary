crypto = Npm.require 'crypto'

@Crypto =
  SHA256: class extends @Crypto.SHA256
    constructor: ->
      @_hash = crypto.createHash 'sha1'

    update: (data) =>
      @_hash.update data

    finalize: =>
      @_hash.digest 'hex'
