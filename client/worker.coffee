@SHA256Worker =
  # defaults
  disableWorker: false
  workerSrc: '/workers/sha256_worker.js'
  chunkSize: 1024 * 32 # bytes

  run: (params) ->
    if !@disableWorker && window && window.Worker
      @.runWebWorker params
    else
      @.runWorkerFallback params

  runWebWorker: (params) ->
    @worker = new WebWorker params
    @worker.run()
    @worker

  runWorkerFallback: (params) ->
    @worker = new WorkerFallback params
    @worker.run()
    @worker

class BaseWorker
  constructor: (params) ->
    self = @
    @_file = params.file
    @_onProgress = params.onProgress or ->
    @_onDone = params.onDone

    if not (@_file and @_onDone)
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

  run: ->
    @worker.postMessage file: @_file, chunkSize: SHA256Worker.chunkSize

class WorkerFallback extends BaseWorker
  constructor: (params) ->
    super params

    @_fileSize = @_file.size
    @_chunkSize = SHA256Worker.chunkSize
    @_chunkStart = 0
    
  run: ->
    self = @
    @_reader = new FileReader()
    @_hash = new Crypto.SHA256()
    @_reader.onload = ->
      self._hash.update @result
      self._handler.progress chunkNumber: @_chunkStart / @_chunkSize, progress: Math.min(@_chunkStart, @_fileSize) / @_fileSize
      self.readNext()
    self.readNext()

  readNext: ->
    start = @_chunkStart
    end = start + @_chunkSize
    # check if all the chunks are read
    if start >= @_fileSize
      sha256 = @_hash.finalize()
      @_handler.done sha256: sha256
    else
      # increase chunkStart
      @_chunkStart = end
      blob = @_file.slice start, end
      @_reader.readAsArrayBuffer blob
    return
