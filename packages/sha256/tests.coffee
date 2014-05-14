testRoot = '/packages/sha256'
pdfFilename = 'tracemonkey.pdf'
pdfHash = '3662ff519e485810520552bf301d8c3b2b917fd2f83303f4965d7abed367e113'
chunkSize = 1024 * 2 # bytes

Tinytest.addAsync 'sha256worker test by vjeko', (test, onComplete) ->
  isDefined = false
  try
    hash = new Crypto.SHA256
    isDefined = true

  # ----------- testchunks ----------------
  testChunks = (pdf) ->
    sendChunk = () ->
      chunkEnd = chunkStart + chunkSize
      chunkData = pdf.slice(chunkStart, chunkEnd)

      hash.update
        data: chunkData
      chunkStart += chunkSize

    chunkStart = 0
    streamLength = pdf.length

    sendChunk() while chunkStart < streamLength
    hash.finalize
      onDone: (sha256) ->
        test.equal sha256, pdfHash
        onComplete()
  # ----------------------------------------

  test.isTrue isDefined, "Crypto.SHA256 is not defined"
  test.isTrue Package['sha256'].Crypto.SHA256, "Package.sha256.Crypto.SHA256 is not defined"

  if Meteor.isClient
    # Random query parameter to prevent caching
    pdfPath = "#{ testRoot }/#{ pdfFilename }?#{ Random.id() }"
    pdf = null

    # test whole file
    oReq = new XMLHttpRequest()
    hash = new Crypto.SHA256
    oReq.open "GET", pdfPath, true
    oReq.onload = ->
      hash.update
        data: oReq.response
      hash.finalize
        onDone: (sha256) ->
          test.equal sha256, pdfHash
    oReq.responseType = 'arraybuffer'
    oReq.send null

    # test chunks
    oReq = new XMLHttpRequest()
    oReq.open "GET", pdfPath, true
    oReq.onload = ->
      testChunks (oReq.response)
    oReq.responseType = 'buffer'
    oReq.send null
  else
    bin = Assets.getBinary pdfFilename
    pdf = new Buffer new Uint8Array bin.buffer

    # testing chunks on server
    #testChunks(pdf)
    #onComplete()

    # import file as blob
    console.log "Importing file"
    hash = new Crypto.SHA256
    hash.update
      data: pdf
    sha256 = hash.finalize()

    test.equal sha256, pdfHash
    onComplete()


