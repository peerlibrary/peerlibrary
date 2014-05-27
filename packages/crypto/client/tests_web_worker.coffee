globals = @

# Web worker tests

Tinytest.addAsync 'Forcing web worker: Sending complete file as ArrayBuffer, checking hash', (test, onComplete) ->
  globals.queue.push () ->
    globals.createHash()
    test.equal globals.hash.worker.constructor.name, 'WebWorker',
               'Fallback worker not allowed in web worker test'
    globals.hash.update globals.pdf
    globals.hash.finalize (error, result) ->
      test.equal error, null
      test.equal result, pdfHash
      onComplete()

  globals.processQueue()

Tinytest.addAsync 'Forcing web worker: Sending complete file as Blob, checking hash', (test, onComplete) ->
  globals.queue.push () ->
    blob = new Blob [globals.pdf]
    globals.createHash()
    test.equal globals.hash.worker.constructor.name, 'WebWorker',
               'Fallback worker not allowed in web worker test'
    globals.hash.update blob
    globals.hash.finalize (error, result) ->
      test.equal error, null
      test.equal result, pdfHash
      onComplete()
  globals.processQueue()

Tinytest.addAsync 'Forcing web worker: Sending file in regular chunks, checking hash', (test, onComplete) ->
  globals.queue.push () ->
    globals.createHash()
    test.equal globals.hash.worker.constructor.name, 'WebWorker',
               'Fallback worker not allowed in web worker test'
    globals.chunkStart = 0
    globals.sendChunk() while globals.chunkStart < pdf.byteLength

    globals.hash.finalize (error, result) ->
      test.equal error, null
      test.equal result, pdfHash
      onComplete()
  globals.processQueue()

Tinytest.addAsync 'Forcing web worker: Sending file in irregular chunks, check hashing', (test, onComplete) ->
  globals.queue.push () ->
    globals.createHash()
    test.equal globals.hash.worker.constructor.name, 'WebWorker',
               'Fallback worker not allowed in web worker test'
    globals.chunkStart = 0
    while globals.chunkStart < globals.pdf.byteLength
      globals.sendChunk true # true is for random
    globals.hash.finalize (error, result) ->
      test.equal error, null
      test.equal result, pdfHash
      onComplete()
  globals.processQueue()

Tinytest.addAsync 'Forcing web worker: Checking progress callback', (test, onComplete) ->
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

    test.equal globals.hash.worker.constructor.name, 'WebWorker',
               'Fallback worker not allowed in web worker test'

    globals.hash.update globals.pdf
    globals.hash.finalize (error, result) ->
      onComplete()
  globals.processQueue()
