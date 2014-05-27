globals = @
@fileLoaded = false
@queue = []

# Process queue
@processQueue = () ->
  return if not fileLoaded
  test() while test = queue.shift()

# Generic tests

Tinytest.addAsync 'Checking package visibility', (test, onComplete) ->
  globals.queue.push () ->
    globals.createHash()
    test.isTrue globals.isDefined, "Crypto.SHA256 is not defined"
    test.isTrue Package['crypto'].Crypto.SHA256, "Package.sha256.Crypto.SHA256 is not defined"
    onComplete()
  globals.processQueue()

Tinytest.addAsync 'Checking file size', (test, onComplete) ->
  globals.queue.push () ->
    test.equal globals.pdf.byteLength, pdfByteLength
    onComplete()
  globals.processQueue()
