globals = @

for disableWorker in [false, true]
  testAsyncMulti "crypto - sending complete file as ArrayBuffer, checking hash (disableWorker: #{ disableWorker })", [
    (test, expect) ->
      globals.downloadPdf expect globals.downloadComplete
  ,
    (test, expect) ->
      globals.createHash
        disableWorker: disableWorker
      globals.hash.update globals.pdf
      globals.hash.finalize expect (error, result) ->
        test.equal error, null
        test.equal result, pdfHash
  ]

  testAsyncMulti "crypto - sending complete file as Blob, checking hash (disableWorker: #{ disableWorker })", [
    (test, expect) ->
      globals.downloadPdf expect globals.downloadComplete
  ,
    (test, expect) ->
      blob = new Blob [globals.pdf]
      globals.createHash
        disableWorker: disableWorker
      globals.hash.update blob
      globals.hash.finalize expect (error, result) ->
        test.equal error, null
        test.equal result, pdfHash
  ]

  testAsyncMulti "crypto - sending file in regular chunks, checking hash (disableWorker: #{ disableWorker })", [
    (test, expect) ->
      globals.downloadPdf expect globals.downloadComplete
  ,
    (test, expect) ->
      globals.createHash
        disableWorker: disableWorker
      globals.chunkStart = 0
      globals.sendChunk() while globals.chunkStart < pdf.byteLength
  
      globals.hash.finalize expect (error, result) ->
        test.equal error, null
        test.equal result, pdfHash
  ]

  testAsyncMulti "crypto - sending file in irregular chunks, checking hash (disableWorker: #{ disableWorker })", [
    (test, expect) ->
      globals.downloadPdf expect globals.downloadComplete
  ,
    (test, expect) ->
      globals.createHash
        disableWorker: disableWorker
      globals.chunkStart = 0
      while globals.chunkStart < globals.pdf.byteLength
        globals.sendChunk true # true is for random
      globals.hash.finalize expect (error, result) ->
        test.equal error, null
        test.equal result, pdfHash
  ]

  testAsyncMulti "crypto - progress callback (disableWorker: #{ disableWorker })", [
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
        disableWorker: disableWorker
        onProgress: (progress) ->
          expectedProgress += progressStep
          expectedProgress = 1 if expectedProgress > 1
          test.equal round(progress), round(expectedProgress)
  
      globals.hash.update globals.pdf
      globals.hash.finalize expect ->
  ]
