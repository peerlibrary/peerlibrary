hash = null
isDefined = false
createHash = () ->
  isDefined = false
  try
    hash = new Crypto.SHA256
    isDefined = true

bin = Assets.getBinary pdfFilename
pdf = new Buffer new Uint8Array bin.buffer

globals = @

Tinytest.add 'Checking package visibility', (test) ->
  createHash()
  test.isTrue isDefined, "Crypto.SHA256 is not defined"
  test.isTrue Package['sha256'].Crypto.SHA256, "Package.sha256.Crypto.SHA256 is not defined"

Tinytest.add 'Checking file size', (test) ->
  test.equal pdf.length, pdfByteLength

Tinytest.add 'Sending complete file', (test) ->
  createHash()
  hash.update
    data: pdf
  sha256 = hash.finalize()
  test.equal sha256, pdfHash

Tinytest.add 'Sending file in regular chunks', (test) ->
  createHash()
  globals.chunkStart = 0
  while globals.chunkStart < pdf.length
    globals.sendChunk
      pdf: pdf,
      hash: hash
  sha256 = hash.finalize()
  test.equal sha256, pdfHash

Tinytest.add 'Sending file in irregular chunks', (test) ->
  createHash()
  globals.chunkStart = 0
  while globals.chunkStart < pdf.length
    globals.sendChunk
      pdf: pdf,
      hash: hash,
      random: true
  sha256 = hash.finalize()
  test.equal sha256, pdfHash
