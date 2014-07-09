globals = @

# Fallback Worker tests

testAsyncMulti "[WorkerFallback] Sending complete file as ArrayBuffer, checking hash", [
  (test, expect) ->
    globals.downloadPdf expect globals.downloadComplete
,
  (test, expect) ->
    globals.createHash
      disableWorker: true
    globals.hash.update globals.pdf
    globals.hash.finalize expect (error, result) ->
      test.equal error, null
      test.equal result, pdfHash
]

testAsyncMulti "[WorkerFallback] Sending complete file as Blob, checking hash", [
  (test, expect) ->
    globals.downloadPdf expect globals.downloadComplete
,
  (test, expect) ->
    blob = new Blob [globals.pdf]
    globals.createHash
      disableWorker: true
    globals.hash.update blob
    globals.hash.finalize expect (error, result) ->
      test.equal error, null
      test.equal result, pdfHash
]

testAsyncMulti "[WorkerFallback] Sending file in regular chunks, checking hash", [
  (test, expect) ->
    globals.downloadPdf expect globals.downloadComplete
,
  (test, expect) ->
    globals.createHash
      disableWorker: true
    globals.chunkStart = 0
    globals.sendChunk() while globals.chunkStart < pdf.byteLength

    globals.hash.finalize expect (error, result) ->
      test.equal error, null
      test.equal result, pdfHash
]

testAsyncMulti "[WorkerFallback] Sending file in irregular chunks, check hashing", [
  (test, expect) ->
    globals.downloadPdf expect globals.downloadComplete
,
  (test, expect) ->
    globals.createHash
      disableWorker: true
    globals.chunkStart = 0
    while globals.chunkStart < globals.pdf.byteLength
      globals.sendChunk true # true is for random
    globals.hash.finalize expect (error, result) ->
      test.equal error, null
      test.equal result, pdfHash
]

testAsyncMulti "[WorkerFallback] Checking progress callback", [
  (test, expect) ->
    globals.downloadPdf expect globals.downloadComplete
,
  (test, expect) ->
    round = (number) ->
      number.toPrecision 5
    chunkCount = globals.pdf.byteLength / globals.chunkSize
    progressStep = 1 / chunkCount
    expectedProgress = 0

    globals.createHash
      size: pdf.byteLength
      disableWorker: true
      onProgress: (progress) ->
        expectedProgress += progressStep
        expectedProgress = 1 if expectedProgress > 1
        test.equal round(progress), round(expectedProgress)

    globals.hash.update globals.pdf
    globals.hash.finalize expect ->
]
