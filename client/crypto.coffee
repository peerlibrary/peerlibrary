bin2hex = (array) ->
  hexTab = '0123456789abcdef'
  str = ''
  for a in array
    str += hexTab.charAt((a >>> 4) & 0xF) + hexTab.charAt(a & 0xF)
  str

@Crypto =
  SHA256: class extends @Crypto.SHA256
    constructor: ->
      @_hash = new Digest.SHA256()

    update: (data) =>
      @_hash.update data

    finalize: =>
      bin2hex new Uint8Array @_hash.finalize()
