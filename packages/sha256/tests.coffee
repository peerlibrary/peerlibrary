testRoot = '/packages/sha256'
pdfFilename = 'tracemonkey.pdf'
pdfHash = '3662ff519e485810520552bf301d8c3b2b917fd2f83303f4965d7abed367e113'
pdfByteLength = 1016315
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
        test.equal "chunks " + sha256, "chunks " + pdfHash
        onComplete()
  # ----------------------------------------

  test.isTrue isDefined, "Crypto.SHA256 is not defined"
  #test.isTrue Package['sha256'].Crypto.SHA256, "Package.sha256.Crypto.SHA256 is not defined"

  console.log "Got here"
  if Meteor.isClient
    # Random query parameter to prevent caching
    pdfPath = "#{ testRoot }/#{ pdfFilename }?#{ Random.id() }"
    pdf = null

    # test whole file
    console.log "Getting " + pdfPath
    HTTP.get pdfPath, (error, result) ->
      test.equal result.statusCode, 200
      test.equal "ByteLength " + result.content.length, "ByteLength " + pdfByteLength
      hash = new Crypto.SHA256
      hash.update
        data: result.content
      hash.finalize
        onDone: (sha256) ->
          console.log sha256
          test.equal "whole " + sha256, "whole " + pdfHash
          onComplete()

    # test chunks
    HTTP.get pdfPath, (error, result) ->
      testChunks (result.content)
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
    console.log sha256

    test.equal sha256, pdfHash
    onComplete()


