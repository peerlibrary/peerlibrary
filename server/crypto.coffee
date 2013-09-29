crypto = Npm.require 'crypto'

@Crypto =
  sha256: (string) ->
    crypto.createHash('sha256').update(string).digest('hex')
