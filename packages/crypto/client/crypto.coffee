Crypto =
  browserSupport:
    useWorker: null
    transferrable: null

  SHA256: class extends Crypto.SHA256
    # defaults
    disableWorker: false
    workerSrc: '/packages/crypto/assets/web-worker.js'
    chunkSize: 1024 * 32 # bytes
    transfer: true
    size: null
    constructor: (params) ->
      # params:
      #       disableWorker -> boolean (optional)
      #       workerSrc -> string (optional)
      #                    override default location of script to be opened in worker thread
      #       chunkSize -> integer (optional)
      #                    override default chunk size in bytes
      #                    chunks are sent to Worker one by one
      #                    smaller chunks result with less memory allocation
      #       onProgress -> progress callback function (optional)
      #                     arguments:
      #                              progress -> float, between 0 and 1 (inclusive)
      #       size -> complete file size (optional)
      if params
        if params.disableWorker
          @disableWorker = params.disableWorker
        if params.workerSrc
          @workerSrc = params.workerSrc
        if params.chunkSize
          @chunkSize = params.chunkSize
        @onProgress = params.onProgress or ->
        if params.size
          size = params.size

      bs = Crypto.browserSupport
      testArray = null
      # https://developer.mozilla.org/en-US/docs/Web/API/ArrayBuffer#slice%28%29
      # http://stackoverflow.com/a/10101213
      if not ArrayBuffer.prototype.slice
        ArrayBuffer.prototype.slice = (start, end) ->
          that = new UInt8Array this
          if typeof end == "undefined"
            end = that.length
          result = new ArrayBuffer end - start
          resultArray = new UInt8Array result
          for i in [0..resultArray.length]
            resultArray[i] = that[i+start]
          result

      if not @disableWorker and bs.useWorker == null
        testArray = testArray or new ArrayBuffer 8
        worker = null
        transferrable = false

        if typeof window != "undefined" and window.Worker
          try
            worker = new WebWorker @, size, @onProgress, @workerSrc,
                                   @chunkSize
            try
              worker.worker.postMessage
                message: 'test'
                data: testArray,
                  [testArray]
              transferrable = not testArray.byteLength
            catch e
              transferrable = false
              worker.enqueue
                type: 'array'
                size: 0
                data: testArray
                message: 'ping'
                transferrable: transferrable

        if not worker
          worker = new WorkerFallback @, size, @onProgress, @chunkSize
          bs.useWorker = false
          bs.transferrable = false

        else if transferrable
          bs.useWorker = true
          bs.transferrable = true
        # if transferrable is false, even if Worker is set at this point
        # we need to wait for 'pong' answer from Worker because
        # structured copy may not work

      else
        if not @disableWorker and bs.useWorker == true
          worker = new WebWorker @, size, @onProgress, @workerSrc,
                                 @chunkSize
        else
          worker = new WorkerFallback @, size, @onProgress, @chunkSize

      @worker = worker

    update: (data, callback) ->
      # data -> File, Blob or ArrayBuffer (required), chunk of data to be added for hash computation
      # callback -> callback function (optional) to be called after data is processed
      #     arguments:
      #             error -> Error instance or null if there is no error
      #             result -> returns null
      if not data
        throw new Error "No data given"
      if not @worker
        throw new Error "Worker is destroyed"

      params =
        message: 'update'
        data: data
        onDone: callback or ->
      if params.data instanceof Blob
        params.type = 'blob'
        params.size = params.data.size
       else
        params.type = 'array'
        params.size = params.data.byteLength
      if not params.transfer
        params.transfer = false
      params.onDone = callback
      @worker.enqueue params

    finalize: (callback) ->
      # callback -> callback function (required)
      #  arguments:
      #           error -> Error instance or null if there is no error
      #           result -> string, sha256 hash computed from data chunks
      #                     or null if error is raised
      if not callback
        throw new Error "callback not given!"
      if not @worker
        throw new Error "Worker is destroyed"

      params =
        message: 'finalize'
        onDone: callback
        size: 0
      @worker.enqueue params

    destroy: ->
      delete @worker

    switchWorker: ->
      # Switches from web worker to fallback worker
      fallbackWorker = new WorkerFallback @, @worker.totalsize,
                                          @onProgress, @chunkSize
      fallbackWorker.enqueue @worker.queue
      delete @worker
      @worker = fallbackWorker
                    #useWorker, transferrable

class BaseWorker
  constructor: (@instance, @totalSize, @onProgress, @chunkSize) ->
    self = @
    @chunkStart = 0
    @busy = false
    @queue = []
    @current = null
    @totalSizeQueued = 0
    @totalSizeProcessed = 0

    @handler =
      progress: ->
        progress = self.totalSizeProcessed / (self.totalSize or self.totalSizeQueued)
        self.onProgress? progress
        self.busy = false
        self.flush()

       done: (result) ->
        self.current?.onDone? null, result

      error: (error) ->
        self.current?.onDone? error, null

      pong: (params) ->
        if params.data instanceof ArrayBuffer
          Crypto.browserSupport.useWorker = true
          self.busy = false
          self.flush()
        else
          Crypto.browserSupport.useWorker = false
          self.instance.switchWorker()

  enqueue: (params) ->
    if params instanceof Array
      @enqueue item for item in params
    else
      @totalSizeQueued += params.size
      @queue.push params
    @flush()

  flush: () ->
    return if @busy
    @busy = true

    # check if current chunk is processed completely
    if @current and (@chunkStart >= @current.size)
      @handler.done
        error: null,
        result: null
      @current = null

    if not @current
      @chunkStart = 0
      @current = @queue.shift() or null
      if not @current
        return @busy = false

    if @current.message == 'finalize'
      @finalize()
      return

    if @current.message == 'ping'
      @worker.postMessage
        message: 'ping'
        data: @current.data
      return

    # read next chunk (or part of chunk)
    start = @chunkStart
    end = start + @chunkSize
    if end > @current.size
      end = @current.size
    @chunkStart = end
    chunk = @current.data.slice start, end
    @totalSizeProcessed += end - start
    if @current.type == 'blob'
      @readBlob chunk
    else
      @processChunk chunk

  readBlob: (blob) ->
    self = @
    reader = new FileReader()
    reader.onload = ->
      self.processChunk @result
    reader.readAsArrayBuffer blob

  processChunk: (chunk) ->
    throw new Error "Not implemented!"

  finalize: (params) ->
    throw new Error "Not implemented!"

  destroy: ->
    throw new Error "Not implemented!"

class WebWorker extends BaseWorker
  constructor: (instance, size, onProgress, workerSrc, chunkSize) ->
    super instance, size, onProgress, chunkSize
    @worker = new Worker workerSrc

    self = @
    @worker.onmessage = (oEvent) ->
      data = oEvent.data.data
      message = oEvent.data.message
      self.handler[message] data

    @worker.onerror = (error) ->
      self.handler.error error
      self.destroy()

  processChunk: (chunk) ->
    message = chunk: chunk, message: 'update'
    if @transferrable
      @worker.postMessage message, [params.chunk]
    else
      @worker.postMessage message

  finalize: ->
    @worker.postMessage
      message: 'finalize'

  destroy: ->
    @worker.terminate()
    @instance.destroy()


class WorkerFallback extends BaseWorker
  constructor: (instance, size, onProgress, chunkSize) ->
    super instance, size, onProgress, chunkSize
    @hash = new Digest.SHA256

  _bin2hex: (array) ->
    hexTab = '0123456789abcdef'
    str = ''
    for a in array
      str += hexTab.charAt((a >>> 4) & 0xF) + hexTab.charAt(a & 0xF)
    str

  processChunk: (chunk) ->
    try
      @hash.update chunk
    catch e
      @handler.done e, null
      @destroy()
    @handler.progress()

  finalize: ->
    error = null
    sha256 = null
    try
      binaryData = @hash.finalize()
      fin = new Uint8Array binaryData
      sha256 = @_bin2hex fin
      @handler.done sha256
    catch e
      error = e
      @handler.error error

  destroy: ->
    @instance.destroy()
