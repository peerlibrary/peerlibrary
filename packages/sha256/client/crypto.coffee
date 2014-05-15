@Crypto =
  workerSrc: '/packages/sha256/web-worker.js'
  chunkSize: 1024 * 32 # bytes

  SHA256: class extends Crypto.SHA256
    # defaults
    disableWorker: false
    _chunkNumber: 0

    constructor: (params) ->
      if params?
        if params.disableWorker?
          @disableWorker = params.disableWorker
        if params.workerSrc?
          Crypto.workerSrc = params.workerSrc
        if params.chunkSize?
          Crypto.chunkSize = params.chunkSize

      if !@disableWorker && typeof window != "undefined" && window.Worker
        @worker = new WebWorker
      else
        @worker = new WorkerFallback

    update: (params) ->
      console.log typeof params.data
      if params.onProgress?
        @worker.setOnProgress(params.onProgress)
      @_chunks = true
      console.log "Crypto sending chunk to worker"
      @worker.sendChunk
        chunk: params.data
        chunkNumber: @_chunkNumber++

    finalize: (params) ->
      if not @_chunks
        throw new Error('Unable to finalize - no chunks sent')
      if params.onDone?
        @worker.setOnDone(params.onDone)
      @worker.finalize()
      @_chunks = false # reset chunks flag

class BaseWorker
  constructor: (params) ->
    self = @
    @_onProgress = ->
    @_onProgressExternal = ->
    @_onDone = ->
  
    @_handler =
      progress: (data) ->
        self._onProgress data
        self._nextChunk()
      done: (data) ->
        self._onDone data.sha256

  setOnDone: (onDone) ->
    @_onDone = onDone
  
  setOnProgress: (onProgress) ->
    @_onProgress = onProgress
    

class WebWorker extends BaseWorker
  _busy: false
  _buffer: []

  constructor: (params) ->
    super params
    @worker = new Worker Crypto.workerSrc
    self = @
    @worker.onmessage = (oEvent) ->
      data = oEvent.data.data
      message = oEvent.data.message
      self._handler[message] data

  _nextChunk: () ->
    console.log "Received chunk ack"
    @_busy = false
    @_flush()

  _flush: () ->
    console.log "Flushing"
    if not @_busy and @_buffer.length > 0
      chunk = @_buffer.shift()
      @_busy = true
      @worker.postMessage chunk

  sendChunk: (chunk) ->
    console.log "Adding chunk to buffer"
    chunk.message = 'chunk'
    @_buffer.push chunk
    @_flush()

  finalize: () ->
    console.log "Adding final chunk to buffer"
    @_buffer.push
      message: 'finalize'
    @_flush()

class WorkerFallback extends BaseWorker
  constructor: (params) ->
    super params

    @_chunkSize = Crypto.chunkSize
    @_chunkStart = 0
    @_hash = new Digest.SHA256()

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

  sendChunk: (chunk) ->
    @_hash.update chunk.data

  _bin2hex: (array) ->
    hexTab = '0123456789abcdef'
    str = ''
    for a in array
      str += hexTab.charAt((a >>> 4) & 0xF) + hexTab.charAt(a & 0xF)
    str

  finalize: ->
    fin = new Uint8Array @_hash.finalize()
    sha256 = @_bin2hex fin
    @_handler.done sha256: sha256
  

