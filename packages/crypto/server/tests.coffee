globals = @
bin = Assets.getBinary pdfFilename
globals.pdf = new Buffer new Uint8Array bin.buffer

Tinytest.add 'Checking package visibility', (test) ->
  globals.createHash()
  test.isTrue globals.isDefined, "Crypto.SHA256 is not defined"
  test.isTrue Package['crypto'].Crypto.SHA256, "Package.sha256.Crypto.SHA256 is not defined"

Tinytest.add 'Checking file size', (test) ->
  test.equal globals.pdf.length, pdfByteLength

Tinytest.add 'Sending complete file as Buffer, checking hash', (test) ->
  globals.createHash()
  globals.hash.update
    data: globals.pdf
  globals.hash.finalize
    onDone: (error, result) ->
      test.equal error, null
      test.equal result, pdfHash

Tinytest.add 'Sending file in regular chunks, checking hash', (test) ->
  globals.createHash()
  globals.chunkStart = 0
  while globals.chunkStart < globals.pdf.length
    globals.sendChunk()
  globals.hash.finalize
    onDone: (error, result) ->
      test.equal error, null
      test.equal result, pdfHash

Tinytest.add 'Sending file in irregular chunks, checking hash', (test) ->
  globals.createHash()
  globals.chunkStart = 0
  while globals.chunkStart < globals.pdf.length
    globals.sendChunk true # true is for random
  globals.hash.finalize
    onDone: (error, result) ->
      test.equal error, null
      test.equal result, pdfHash
