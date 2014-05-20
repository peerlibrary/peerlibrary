@testRoot = '/packages/sha256'
@pdfFilename = 'tracemonkey.pdf'
@pdfHash = '3662ff519e485810520552bf301d8c3b2b917fd2f83303f4965d7abed367e113'
@pdfByteLength = 1016315
@chunkSize = 1024 * 2 # bytes
@chunkStart = 0

@sendChunk = (params) ->
  if params.random
    rnd = 1
  else
    rnd = 0
  currentChunkSize = @chunkSize * ( 1 + Math.random() * 2 * rnd )
  chunkEnd = @chunkStart + currentChunkSize
  chunkData = params.pdf.slice(@chunkStart, chunkEnd)
  params.hash.update
    data: chunkData
  @chunkStart += currentChunkSize

