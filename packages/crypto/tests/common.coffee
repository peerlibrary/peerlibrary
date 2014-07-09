@TEST_ROOT = '/packages/crypto'
@PDF_FILENAME = 'assets/test.pdf'
@PDF_HASH = '750cb3269e8222c05548184a2814b8f4b102e9157fe5fd498cfcaeb237fbd38f'
@PDF_BYTE_LENGTH = 13069
@CHUNK_SIZE = 2 * 1024 # bytes

@getChunk = (pdf, chunkStart, random) ->
  random ?= 0
  factor = Math.random() * 2
  currentChunkSize = Math.round(CHUNK_SIZE * (1 + factor * random))
  chunkEnd = chunkStart + currentChunkSize
  chunkEnd = @PDF_BYTE_LENGTH if chunkEnd > @PDF_BYTE_LENGTH
  chunkData = pdf.slice chunkStart, chunkEnd
  chunkStart += currentChunkSize
  chunkData: chunkData
  chunkStart: chunkStart

@createHash = (params) ->
  params = _.defaults params or {},
    disableWorker: null
    onProgress: null
    size: null
  new Crypto.SHA256 _.extend params,
    chunkSize: @CHUNK_SIZE
