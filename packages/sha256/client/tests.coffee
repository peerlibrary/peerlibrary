isDefined = false
hash = null
createHash = () ->
  isDefined = false
  try
    hash = new Crypto.SHA256
    isDefined = true

globals = @

# Download file
pdfPath = "#{ testRoot }/#{ pdfFilename }?" + Math.random()
oReq = new XMLHttpRequest
oReq.open "GET", pdfPath, true
oReq.responseType = 'arraybuffer'
oReq.onload = (oEvent) ->
  pdf = oReq.response

  Tinytest.add 'Checking package visibility', (test) ->
    createHash()
    test.isTrue isDefined, "Crypto.SHA256 is not defined"
    test.isTrue Package['sha256'].Crypto.SHA256, "Package.sha256.Crypto.SHA256 is not defined"

  Tinytest.add 'Checking file size', (test) ->
    test.equal pdf.byteLength, pdfByteLength
  
  Tinytest.addAsync 'Sending complete file', (test, onComplete) ->
    createHash()
    hash.update
      data: pdf   # Send complete file to Crypto
    hash.finalize
      onDone: (sha256) ->
        console.log sha256
        test.equal sha256, pdfHash
        onComplete()
    oReq.send null

  Tinytest.addAsync 'Sending file in regular chunks', (test, onComplete) ->
    globals.chunkStart = 0
    while globals.chunkStart < pdf.byteLength
      globals.sendChunk
        pdf: pdf,
        hash: hash
    hash.finalize
      onDone: (sha256) ->
        test.equal sha256, pdfHash
        onComplete()

  Tinytest.addAsync 'Sending file in irregular chunks', (test, onComplete) ->
    globals.chunkStart = 0
    while globals.chunkStart < pdf.byteLength
      globals.sendChunk
        pdf: pdf,
        hash: hash,
        random: 1
      hash.finalize
        onDone: (sha256) ->
          test.equal sha256, pdfHash
          onComplete()

oReq.send null
