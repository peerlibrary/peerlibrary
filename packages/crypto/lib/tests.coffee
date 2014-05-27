@testRoot = '/packages/crypto'
@pdfFilename = 'assets/test.pdf'
@pdfHash = '750cb3269e8222c05548184a2814b8f4b102e9157fe5fd498cfcaeb237fbd38f'
@pdfByteLength = 13069
@chunkSize = 1024 * 2 # bytes
@chunkStart = 0
@pdf = null

@sendChunk = (random) ->
  random = 0 if not random?
  factor = Math.random() * 2
  currentChunkSize = Math.round(chunkSize * (1 + factor * random))
  chunkEnd = chunkStart + currentChunkSize
  chunkEnd = @pdfByteLength if chunkEnd > @pdfByteLength
  chunkData = pdf.slice(chunkStart, chunkEnd)
  hash.update chunkData
  chunkStart += currentChunkSize

@isDefined = false
@hash = null
@createHash = (params) ->
  if not params
    params =
      disableWorker: null
      onProgress: null
      size: null
  @isDefined = true
  try
    @hash = new Crypto.SHA256
      chunkSize: @chunkSize
      disableWorker: params.disableWorker or false
      onProgress: params.onProgress or ->
      size: params.size
    @isDefined = true

