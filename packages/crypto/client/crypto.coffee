Crypto =
  SHA256: class extends Crypto.SHA256
    # defaults
    disableWorker: false
    workerSrc: '/packages/crypto/client/web-worker.js'
    chunkSize: 1024 * 32 # bytes

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
        if params.onProgress
          @onProgress = params.onProgress
        if params.size
          @size = params.size

      testArray = new ArrayBuffer(8)

      #test if ArrayBuffers can be sliced, see:
      # https://developer.mozilla.org/en-US/docs/Web/API/ArrayBuffer#slice%28%29

      try
        testArray.slice(0, 4)
        disableSlicing = false
      catch e
        disableSlicing = true

      worker = null
      if !@disableWorker and typeof window != "undefined" and window.Worker
        try
          # if WebWorker constructor fails, it will use Fallback
          worker = new WebWorker \
            @size, \
            (@onProgress or ->), \
            @workerSrc, \
            @chunkSize, \
            testArray
      if not worker
        worker = new WorkerFallback \
          @size, \
          (@onProgress or ->), \
          @chunkSize

      worker.disableSlicing = disableSlicing
      @worker = worker

    update: (params) ->
      # params:
      #       data -> File, Blob or ArrayBuffer (required), chunk of data to be added for hash computation
      #       transfer -> boolean (optional)
      #                   whether chunks should be transferred to Worker (if supported) or not
      #                   transferring is faster and doesn't allocate memory
      #                   once transferred, data is lost in the main thread
      #                   set to `true` if you don't need the data after hash calculation
      #       onDone -> callback function (optional)
      #                 arguments:
      #                         error -> Error instance or null if there is no error
      #                         result -> Integer, 0 if everything is ok, -1 if not
      params.message = 'update'
      if params.data instanceof Blob
        params.type = 'blob'
      else
        params.type = 'array'
      if not params.transfer
        params.transfer = false
      if not params.onDone
        params.onDone = ->
      @worker.queue params

    finalize: (params) ->
      # params:
      #       onDone -> callback function (required)
      #                 arguments:
      #                          error -> Error instance or null if there is no error
      #                          result -> string, sha256 hash computed from data chunks
      params.message = 'finalize'
      if not params.onDone
        throw new Error 'onDone callback not given!'
      @worker.queue params

    destroy: ->
      # terminates the worker to free up resources
      # do not use this (Crypto.SHA256) instance once this method is invoked, if will fail
      # if you really need to, invoke instance.constructor() to start worker again
      # NOTE, this method terminates the worker immediately, make sure it has done all the work
      @worker.destroy()
      delete @worker

class BaseWorker
  constructor: (@globalSize, @onProgress, @chunkSize) ->
    self = @
    @chunkStart = 0
    @globalChunkStart = 0
    @totalSize = 0
    @busy = false
    @buffer = []
    @current = null
    @reader = null
    @globalSizeSet = @globalSize?

    @handler =
      progress: (params) ->
        # progress is undefined
        progress = (self.globalChunkStart + self.chunkStart) / self.globalSize
        progress = 0 if isNaN progress
        self.onProgress? progress # not current.onProgress because onProgress is global
        self.busy = false
        self.flush()
        
      done: (params) ->
        self.globalChunkStart += self.totalSize
        self.current?.onDone? params.error, params.result

  queue: (params) ->
    # if global size is not given, calculate it on the fly
    if not @globalSizeSet and params.data
      @globalSize = (@globalSize or 0) + (params.data.size or params.data.byteLength)
      
    @buffer.push params
    @flush()

  flush: () ->
    return if @busy
    @busy = true

    # check if current chunk is processed completely
    if @chunkStart >= @totalSize
      # calling callback function if current chunk is processed
      @handler.done
        error: null,
        result: 1

      @chunkStart = 0
      @totalSize = 0
      @current = @buffer.shift()
      if !@current
        return @busy = false
      if @current.message == 'update'
        if @current.type == 'blob'
          @totalSize = @current.data.size
          if not @reader
            @setupFileReader()
        else
          @totalSize = @current.data.byteLength
    
    if @current.message == 'finalize'
      @finalize()
      return

    # read next chunk (or part of chunk)
    start = @chunkStart
    end = start + @chunkSize
    if end > @totalSize
      end = @totalSize
    @chunkStart = end
    if @disableSlicing
      # move chunkStart to the end because we send the whole chunk at once
      @chunkStart = @totalSize
      chunk = @current.data
      transfer = @current.transfer
    else
      chunk = @current.data.slice start, end
      transfer = true
    if @current.type == 'blob'
      @reader.readAsArrayBuffer chunk
    else
      @processChunk chunk: chunk, transfer: transfer

  setupFileReader: ->
    self = @
    @reader = new FileReader()
    @reader.onload = ->
      self.processChunk chunk: @result, transfer: true

  processChunk: (chunk) ->
    throw new Error "Not implemented!"

  finalize: (params) ->
    throw new Error "Not implemented!"

  destroy: ->
    throw new Error "Not implemented!"

class WebWorker extends BaseWorker
  constructor: (size, onProgress, workerSrc, chunkSize, testArray) ->
    super size, onProgress, chunkSize
    @worker = new Worker workerSrc
    try
      @worker.postMessage
        message: 'test'
        data: testArray,
          [testArray]
      @transferrable = !testArray.byteLength
    catch e
      @transferrable = false
      @worker.postMessage
        message: 'test'
        data: testArray
    
    self = @
    @worker.onmessage = (oEvent) ->
      data = oEvent.data.data
      message = oEvent.data.message
      self.handler[message] data

  processChunk: (data) ->
    message = chunk: data.chunk, message: 'update'
    if @transferrable and data.transfer
      @worker.postMessage message, [data.chunk]
    else
      @worker.postMessage message

  finalize: ->
    @worker.postMessage
      message: 'finalize'

  destroy: ->
    @worker.terminate()


class WorkerFallback extends BaseWorker
  constructor: (size, onProgress, chunkSize) ->
    super size, onProgress, chunkSize
    @hash = new Digest.SHA256

  _bin2hex: (array) ->
    hexTab = '0123456789abcdef'
    str = ''
    for a in array
      str += hexTab.charAt((a >>> 4) & 0xF) + hexTab.charAt(a & 0xF)
    str

  processChunk: (data) ->
    @hash.update data.chunk
    @handler.progress()
    @handler.done(null, 0)

  finalize: ->
    binaryData = @hash.finalize()
    fin = new Uint8Array binaryData
    sha256 = @_bin2hex fin
    @handler.done
      error: null,
      result: sha256

  destroy: ->
