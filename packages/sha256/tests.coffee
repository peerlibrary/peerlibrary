testRoot = '/packages/sha256'
pdfFilename = 'tracemonkey.pdf'
chunkSize = 1024 * 2 # bytes

Tinytest.addAsync 'sha256worker test by vjeko', (test, onComplete) ->
  isDefined = false
  try
    SHA256Worker
    isDefined = true

  testChunks = (pdf) ->
    sendChunk = () ->
      chunkEnd = chunkStart + chunkSize
      chunkData = pdf.slice(chunkStart, chunkEnd)

      SHA256Worker.addChunk
        chunk: chunkData
      chunkStart += chunkSize

    chunkStart = 0
    streamLength = pdf.length

    sendChunk() while chunkStart < streamLength
    SHA256Worker.finalize(
      (sha256) ->
        onComplete()
    )

  test.isTrue isDefined, "SHA256Worker is not defined"
  test.isTrue Package['sha256'].SHA256Worker, "Package.sha256.SHA256Worker is not defined"

  if Meteor.isClient
    # Random query parameter to prevent caching
    pdfPath = "#{ testRoot }/#{ pdfFilename }?#{ Random.id() }"
    pdf = null

    oReq = new XMLHttpRequest()
    oReq.open "GET", pdfPath, true
    oReq.responseType = 'buffer'

    oReq.onload = ->
      testChunks (oReq.response)

    oReq.send null
  else
    bin = Assets.getBinary pdfFilename
    pdf = new Buffer new Uint8Array bin.buffer
    testChunks(pdf)
    onComplete()


  # import file as blob
  #SHA256Worker.fromFile
  #  file: pdf
  #  onDone: (sha256) ->
  #    return


