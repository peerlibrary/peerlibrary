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
      console.log "update called"
      if params.onProgress?
        @worker.setOnProgress(params.onProgress)
      @_chunks = true
      console.log "Crypto sending chunk to worker"
      @worker.update params.data
      console.log "done"

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
    @_chunkStart = 0
    @_fileSize = 0
  
    @_handler =
      progress: (progress) ->
        self._onProgress progress

      chunkDone: ->
        console.log "web worker callback"
        if not self._chunkStart > 0
          console.log "moving to next buff el"
          # moving to next buffer element
          self._nextBufferElement()
        
      done: (data) ->
        self._onDone data.sha256

  setOnDone: (onDone) ->
    @_onDone = onDone
  
  setOnProgress: (onProgress) ->
    @_onProgress = onProgress

  _readNext: ->
    self = @
    start = @_chunkStart
    end = start + Crypto.chunkSize
    # check if all the chunks are read
    if start >= @_fileSize
      if @_autoFinalize
        @finalize()
    else
      # increase chunkStart
      @_chunkStart = end
      blob = @_file.slice start, end
      @_reader.readAsArrayBuffer blob

  _sendFile: (file) ->
    self = @
    @_file = file
    @_fileSize = @_file.size
    @_reader = new FileReader()
    @_reader.onload = ->
      self._sendChunk @result
      self._handler.progress Math.min(self._chunkStart, self._fileSize) / self._fileSize
      self._readNext()
    self._readNext()

class WebWorker extends BaseWorker
  _busy: false
  _buffer: []

  constructor: (params) ->
    super params
    @_autoFinalize = false
    @worker = new Worker Crypto.workerSrc
    self = @
    @worker.onmessage = (oEvent) ->
      data = oEvent.data.data
      message = oEvent.data.message
      self._handler[message] data

  _nextBufferElement: ->
    @_busy = false
    @_flush()

  _flush: ->
    console.log @_buffer.length
    if not @_busy and @_buffer.length > 0
      data = @_buffer.shift()
      @_busy = true
      if data instanceof Blob or data.byteLength > 2 * Crypto.chunkSize
        console.log "Next buffer element is blob or large chunk - sending file (chunkStart is " + @_chunkStart + ")"
        @_sendFile data
      else
        console.log "Next buffer element is small chunk"
        @_sendChunk data
      @worker.postMessage chunk

  _sendChunk: (data) ->
    console.log "Sending chunk to web worker"
    @worker.postMessage
      chunk: data,
      message: 'chunk',
      chunkNumber: null

  update: (data) ->
    console.log "Buffering received data"
    @_buffer.push data
    @_flush()

  finalize: ->
    console.log "Adding final chunk to buffer"
    @_buffer.push
      message: 'finalize'
    @_flush()

class WorkerFallback extends BaseWorker
  constructor: (params) ->
    super params
    @_hash = new Digest.SHA256()

  update: (data) ->
    @_hash.update data

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
  

