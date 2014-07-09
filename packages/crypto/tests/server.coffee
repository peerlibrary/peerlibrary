getPdf = ->
  pdf = Assets.getBinary PDF_FILENAME
  new Buffer new Uint8Array pdf.buffer

Tinytest.add 'crypto - file size', (test) ->
  pdf = getPdf()
  test.equal pdf.length, PDF_BYTE_LENGTH

Tinytest.add 'crypto - sending complete file as Buffer, checking hash (blocking)', (test) ->
  pdf = getPdf()
  hash = createHash()
  hash.update pdf
  result = hash.finalize()
  test.equal result, PDF_HASH

Tinytest.add 'crypto - sending file in regular chunks, checking hash (blocking)', (test) ->
  pdf = getPdf()
  hash = createHash()
  chunkStart = 0
  while chunkStart < pdf.length
    {chunkData, chunkStart} = getChunk pdf, chunkStart
    hash.update chunkData
  result = hash.finalize()
  test.equal result, PDF_HASH

Tinytest.add 'crypto - sending file in irregular chunks, checking hash (blocking)', (test) ->
  pdf = getPdf()
  hash = createHash()
  chunkStart = 0
  while chunkStart < pdf.length
    {chunkData, chunkStart} = getChunk pdf, chunkStart, true # true is for randomized chunks
    hash.update chunkData
  result = hash.finalize()
  test.equal result, PDF_HASH

Tinytest.addAsync 'crypto - sending complete file as Buffer, checking hash (callback)', (test, onComplete) ->
  pdf = getPdf()
  hash = createHash()
  hash.update pdf, (error) ->
    test.isFalse error, error?.toString?() or error
    hash.finalize (error, result) ->
      test.isFalse error, error?.toString?() or error
      test.equal result, PDF_HASH
      onComplete()

Tinytest.addAsync 'crypto - sending file in regular chunks, checking hash (callback)', (test, onComplete) ->
  pdf = getPdf()
  hash = createHash()
  chunkStart = 0
  async.whilst ->
    chunkStart < pdf.length
  ,
    (callback) ->
      {chunkData, chunkStart} = getChunk pdf, chunkStart
      hash.update chunkData, callback
  ,
    (error) ->
      test.isFalse error, error?.toString?() or error
      hash.finalize (error, result) ->
        test.isFalse error, error?.toString?() or error
        test.equal result, PDF_HASH
        onComplete()

Tinytest.addAsync 'crypto - sending file in irregular chunks, checking hash (callback)', (test, onComplete) ->
  pdf = getPdf()
  hash = createHash()
  chunkStart = 0
  async.whilst ->
    chunkStart < pdf.length
  ,
    (callback) ->
      {chunkData, chunkStart} = getChunk pdf, chunkStart, true # true is for randomized chunks
      hash.update chunkData, callback
  ,
    (error) ->
      test.isFalse error, error?.toString?() or error
      hash.finalize (error, result) ->
        test.isFalse error, error?.toString?() or error
        test.equal result, PDF_HASH
        onComplete()
