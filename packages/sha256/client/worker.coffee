SHA256Worker =
  # defaults
  disableWorker: false
  workerSrc: '/packages/sha256/web-worker.js'
  chunkSize: 1024 * 2 # bytes
  _chunks: false
  _autoChunkNumbers: true
  _chunkNumber: 0
  #_chunkBuffer: new Array
  
  fromFile: (params) ->
    if @_chunks
      throw new Error('Unable to receive file while receiving chunks')
    @initWorker params
    @worker.sendFile params

  addChunk: (params) ->
    if not @_chunks
      @initWorker params
      @_chunks = true
    if not params.chunkNumber?
      if not @_autoChunkNumbers
        throw new Error('Chunk number not defined in manual chunk numbering mode')
      params.chunkNumber = @_chunkNumber
    else
      @_autoChunkNumbers = false
    @worker.sendChunk params
    #@_chunkBuffer[@_chunkNumber] = params.chunk
    @_chunkNumber++

  addRandomizedChunks: ->
    console.log "sending chunks in random order"
    beenThere = new Array
    for i in [1..@_chunkNumber] by 1
      cn = Math.floor( Math.random() * @_chunkNumber )
      cn = Math.floor( Math.random() * @_chunkNumber ) while cn in beenThere
      console.log i + " sending chunk no " + cn
      @worker.sendChunk
        chunk: @_chunkBuffer[cn]
        chunkNumber: cn
      beenThere.push cn

  finalize: (onDone) ->
    if not @_chunks
      throw new Error('Unable to finalize - no chunks sent')
    if not onDone?
      throw new Error('Unable to finalize - callback function not set')
    @worker.setOnDone(onDone)
    #@addRandomizedChunks()
    @worker.finalize()

  initWorker: (params) ->
    if !@disableWorker && typeof window != "undefined" && window.Worker
      @worker = new WebWorker params
    else
      @worker = new WorkerFallback params

class BaseWorker
  _chunkBuffer: new Array
  _currentChunk: 0

  constructor: (params) ->
    self = @
    @_onProgress = params.onProgress or ->
    @_onDone = params.onDone or ->

    @_handler =
      progress: (data) ->
        self._onProgress data
      done: (data) ->
        self._onDone data.sha256

   setOnDone: (onDone) ->
     @_onDone = onDone

class WebWorker extends BaseWorker
  constructor: (params) ->
    super params
    @worker = new Worker SHA256Worker.workerSrc
    self = @
    @_onDone = params.onDone
    @worker.onmessage = (oEvent) ->
      data = oEvent.data.data
      message = oEvent.data.message
      self._handler[message] data
  
  sendFile: (params) ->
    @worker.postMessage message: 'file', file: params.file, chunkSize: SHA256Worker.chunkSize

  sendChunk: (params) ->
    @worker.postMessage message: 'chunk', chunk: params.chunk, chunkNumber: params.chunkNumber

  finalize: (params) ->
    @worker.postMessage message: 'finalize'

class WorkerFallback extends BaseWorker
  constructor: (params) ->
    super params

    @_chunkSize = SHA256Worker.chunkSize
    @_chunkStart = 0
    @_hash = new Crypto.SHA256()

  _flushBuffer: ->
    loop
      break if not @_chunkBuffer[@_currentChunk]?
      @_hash.update @_chunkBuffer[@_currentChunk]
      delete @_chunkBuffer[@_currentChunk]
      @_currentChunk++

  sendFile: (params) ->
    self = @
    @_file = params.file
    @_fileSize = @_file.size
    @_reader = new FileReader()
    @_reader.onload = ->
      self._hash.update @result
      self._handler.progress chunkNumber: @_chunkStart / @_chunkSize, progress: Math.min(@_chunkStart, @_fileSize) / @_fileSize
      self.readNext()
    self.readNext()

  readNext: ->
    self = @
    start = @_chunkStart
    end = start + @_chunkSize
    # check if all the chunks are read
    if start >= @_fileSize
      @finalize()
    else
      # increase chunkStart
      @_chunkStart = end
      blob = @_file.slice start, end
      @_reader.readAsArrayBuffer blob
    return

  sendChunk: (params) ->
    @_chunkBuffer[params.chunkNumber] = params.chunk
    @_flushBuffer()

  finalize: ->
    @_flushBuffer()
    sha256 = @_hash.finalize()
    @_handler.done sha256: sha256
