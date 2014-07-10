# Download file using XMLHttpRequest and not using jQuery or HTTP
# package because they do not support arraybuffer responseType
# See http://bugs.jquery.com/ticket/11461
# and https://github.com/jquery/jquery/pull/1525
getPdf = (callback) ->
  # Random query parameter to prevent caching
  pdfPath = "#{ TEST_ROOT }/#{ PDF_FILENAME }?#{ Random.id() }"
  request = new XMLHttpRequest
  request.open 'GET', pdfPath, true
  request.responseType = 'arraybuffer'
  request.onload = (event) ->
    callback null, request.response
  request.onerror = (event) ->
    callback request.status
  request.send null

testAsyncMulti 'crypto - file size', [
  (test, expect) ->
    getPdf expect (error, pdf) =>
      test.isFalse error, error?.toString?() or error
      test.isTrue pdf
      @pdf = pdf
,
  (test, expect) ->
    test.equal @pdf.byteLength, PDF_BYTE_LENGTH
]

# Disable worker use, use autodetect; add false to force worker use (tests might fail)
for disableWorker in [true, null]
  do (disableWorker) ->
    testAsyncMulti "crypto - sending complete file as ArrayBuffer, checking hash (disableWorker: #{ disableWorker })", [
      (test, expect) ->
        getPdf expect (error, pdf) =>
          test.isFalse error, error?.toString?() or error
          test.isTrue pdf
          @pdf = pdf
    ,
      (test, expect) ->
        onComplete = expect()
        hash = createHash
          disableWorker: disableWorker
        hash.update @pdf, (error) =>
          test.isFalse error, error?.toString?() or error
          hash.finalize (error, result) =>
            test.isFalse error, error?.toString?() or error
            test.equal result, PDF_HASH

             # Cannot reuse consumed hash
            hash.update @pdf, (error) ->
              test.isTrue error
              hash.finalize (error, result) ->
                test.isTrue error
                test.isFalse result
                onComplete()
    ]

    testAsyncMulti "crypto - sending complete file as Blob, checking hash (disableWorker: #{ disableWorker })", [
      (test, expect) ->
        getPdf expect (error, pdf) =>
          test.isFalse error, error?.toString?() or error
          test.isTrue pdf
          @pdf = pdf
    ,
      (test, expect) ->
        onComplete = expect()
        blob = new Blob [@pdf]
        hash = createHash
          disableWorker: disableWorker
        hash.update blob, (error) ->
          test.isFalse error, error?.toString?() or error
          hash.finalize (error, result) ->
            test.isFalse error, error?.toString?() or error
            test.equal result, PDF_HASH
            onComplete()
    ]

    testAsyncMulti "crypto - sending file in regular chunks, checking hash (disableWorker: #{ disableWorker })", [
      (test, expect) ->
        getPdf expect (error, pdf) =>
          test.isFalse error, error?.toString?() or error
          test.isTrue pdf
          @pdf = pdf
    ,
      (test, expect) ->
        onComplete = expect()
        hash = createHash
          disableWorker: disableWorker
        chunkStart = 0
        async.whilst =>
          chunkStart < @pdf.byteLength
        ,
          (callback) =>
            {chunkData, chunkStart} = getChunk @pdf, chunkStart
            hash.update chunkData, callback
        ,
          (error) ->
            test.isFalse error, error?.toString?() or error
            hash.finalize (error, result) ->
              test.isFalse error, error?.toString?() or error
              test.equal result, PDF_HASH
              onComplete()
    ]

    testAsyncMulti "crypto - sending file in irregular chunks, checking hash (disableWorker: #{ disableWorker })", [
      (test, expect) ->
        getPdf expect (error, pdf) =>
          test.isFalse error, error?.toString?() or error
          test.isTrue pdf
          @pdf = pdf
    ,
      (test, expect) ->
        onComplete = expect()
        hash = createHash
          disableWorker: disableWorker
        chunkStart = 0
        async.whilst =>
          chunkStart < @pdf.byteLength
        ,
          (callback) =>
            {chunkData, chunkStart} = getChunk @pdf, chunkStart, true # true is for randomized chunks
            hash.update chunkData, callback
        ,
          (error) ->
            test.isFalse error, error?.toString?() or error
            hash.finalize (error, result) ->
              test.isFalse error, error?.toString?() or error
              test.equal result, PDF_HASH
              onComplete()
    ]

    testAsyncMulti "crypto - progress callback (disableWorker: #{ disableWorker })", [
      (test, expect) ->
        getPdf expect (error, pdf) =>
          test.isFalse error, error?.toString?() or error
          test.isTrue pdf
          @pdf = pdf
    ,
      (test, expect) ->
        onComplete = expect()

        round = (number) ->
          number.toPrecision 5
        chunkCount = @pdf.byteLength / CHUNK_SIZE
        progressStep = 1 / chunkCount
        expectedProgress = 0
        progressCount = 0

        hash = createHash
          size: @pdf.byteLength
          disableWorker: disableWorker
          onProgress: (progress) ->
            expectedProgress += progressStep
            expectedProgress = 1 if expectedProgress > 1
            progressCount++
            test.equal round(progress), round(expectedProgress)

        hash.update @pdf, (error) ->
          test.isFalse error, error?.toString?() or error
          hash.finalize (error, result) ->
            test.isFalse error, error?.toString?() or error
            test.equal result, PDF_HASH
            test.equal progressCount, Math.ceil(chunkCount)
            onComplete()
    ]
