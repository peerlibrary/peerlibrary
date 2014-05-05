SHA256Worker =
  # defaults
  disableWorker: false
  workerSrc: '/packages/sha256/web-worker.js'
  chunkSize: 1024 * 32 # bytes
  _chunks: false

  fromFile: (params) ->
    if @_chunks
      throw new Error('Unable to receive file while receiving chunks')
    @initWorker params
    @worker.sendFile params

  addChunk: (params) ->
    if not @_chunks
      @initWorker params
      @_chunks = true
    @worker.sendChunk params

  finalize: ->
    if not @_chunks
      throw new Error('Unable to finalize - no chunks sent')
    @worker.finalize()

  initWorker: (params) ->
    if !@disableWorker && window && window.Worker
      @worker = new WebWorker params
    else
      @worker = new WorkerFallback params

class BaseWorker
  constructor: (params) ->
    self = @
    @_onProgress = params.onProgress or ->
    @_onDone = params.onDone

    if not @_onDone
      throw new Error('Not enough parameters')

    @_handler = 
      progress: (data) ->
        self._onProgress data

      done: (data) ->
        self._onDone data.sha256

class WebWorker extends BaseWorker
  constructor: (params) ->
    super params
    @worker = new Worker SHA256Worker.workerSrc
    self = @
    @worker.onmessage = (oEvent) ->
      data = oEvent.data.data
      message = oEvent.data.message
      self._handler[message] data

  sendFile: (params) ->
    @worker.postMessage message: 'file', file: params.file, chunkSize: SHA256Worker.chunkSize

  sendChunk: (params) ->
    @worker.postMessage message: 'chunk', chunk: params.chunk

  finalize: (params) ->
    @worker.postMessage message: 'finalize'

class WorkerFallback extends BaseWorker
  constructor: (params) ->
    super params

    @_chunkSize = SHA256Worker.chunkSize
    @_chunkStart = 0
    @_chunks = false
    
  sendFile: (params) ->
    self = @
    @_file = params.file
    @_fileSize = @_file.size
    @_reader = new FileReader()
    @_hash = new Crypto.SHA256()
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

  finalize: ->
    sha256 = @_hash.finalize()
    @_handler.done sha256: sha256   
  
  sendChunk: ->
    #TODO handle chunks in fallback worker
    return  
