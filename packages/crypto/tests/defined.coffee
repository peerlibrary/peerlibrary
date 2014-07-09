Tinytest.add 'crypto - defined', (test) ->
  isDefined = false
  try
    Crypto
    isDefined = true
  test.isTrue isDefined, "Crypto is not defined"
  test.isTrue Package['crypto'].Crypto, "Package.crypto.Crypto is not defined"
