@testRoot = '/packages/crypto'
@pdfFilename = 'test.pdf'
@pdfHash = '750cb3269e8222c05548184a2814b8f4b102e9157fe5fd498cfcaeb237fbd38f'
@pdfByteLength = 13069
@chunkSize = 1024 * 1 # bytes
@chunkStart = 0
@pdf = null

@sendChunk = (random) ->
  random = 0 if not random?
  currentChunkSize = chunkSize * ( 1 + Math.random() * 2 * random )
  chunkEnd = chunkStart + currentChunkSize
  chunkData = pdf.slice(chunkStart, chunkEnd)
  hash.update
    data: chunkData
  chunkStart += currentChunkSize

@isDefined = false
@hash = null
@createHash = () ->
  @isDefined = true
  try
    @hash = new Crypto.SHA256
      chunkSize: @chunkSize
    @isDefined = true

