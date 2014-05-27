globals = @

# Fallback Worker tests

Tinytest.addAsync '[WorkerFallback] Sending complete file as ArrayBuffer, checking hash', (test, onComplete) ->
  globals.queue.push () ->
    try
      globals.createHash
        disableWorker: true
      globals.hash.update globals.pdf
      globals.hash.finalize (error, result) ->
        test.equal error, null
        test.equal result, pdfHash
        onComplete()
    catch error
      test.fail(error)
      onComplete()

  globals.processQueue()

Tinytest.addAsync '[WorkerFallback] Sending complete file as Blob, checking hash', (test, onComplete) ->
  globals.queue.push () ->
    try
      blob = new Blob [globals.pdf]
      globals.createHash
        disableWorker: true
      globals.hash.update blob
      globals.hash.finalize (error, result) ->
        test.equal error, null
        test.equal result, pdfHash
        onComplete()
    catch error
      test.fail(error)
      onComplete()
  globals.processQueue()

Tinytest.addAsync '[WorkerFallback] Sending file in regular chunks, checking hash', (test, onComplete) ->
  globals.queue.push () ->
    globals.createHash
      disableWorker: true
    globals.chunkStart = 0
    globals.sendChunk() while globals.chunkStart < pdf.byteLength

    globals.hash.finalize (error, result) ->
      test.equal error, null
      test.equal result, pdfHash
      onComplete()
  globals.processQueue()

Tinytest.addAsync '[WorkerFallback] Sending file in irregular chunks, check hashing', (test, onComplete) ->
  globals.queue.push () ->
    globals.createHash
      disableWorker: true
    globals.chunkStart = 0
    while globals.chunkStart < globals.pdf.byteLength
      globals.sendChunk true # true is for random
    globals.hash.finalize (error, result) ->
      test.equal error, null
      test.equal result, pdfHash
      onComplete()
  globals.processQueue()

Tinytest.addAsync '[WorkerFallback] Checking progress callback', (test, onComplete) ->
  round = (number) ->
    number.toPrecision 5
  globals.queue.push () ->
    chunkCount = globals.pdf.byteLength / globals.chunkSize
    progressStep = 1 / chunkCount
    expectedProgress = 0

    globals.createHash
      size: pdf.byteLength
      onProgress: (progress) ->
        expectedProgress += progressStep
        expectedProgress = 1 if expectedProgress > 1
        test.equal round(progress), round(expectedProgress)

    globals.hash.update globals.pdf
    globals.hash.finalize (error, result) ->
      onComplete()
  globals.processQueue()
