# TODO: How to properly find out the location of this? And know the query string value?
WORKER_SRC = '/packages/crypto/assets/worker.js'
CHUNK_SIZE = 128 * 1024 # bytes

Crypto =
  _browserSupport:
    useWorker: null
    transferable: null

  SHA256: class extends Crypto.SHA256
    # Defaults
    disableWorker: false
    workerSrc: WORKER_SRC
    chunkSize: CHUNK_SIZE
    size: null

    # params: (in addition to superclass)
    #   disableWorker: boolean (optional)
    #   workerSrc: string, override default location of script to be opened in worker thread (optional)
    #   chunkSize: integer, override default chunk size in bytes (optional)
    #              chunks are send to the worker one by one, smaller chunks result in less memory allocation, but more overhead
    constructor: (params) ->
      super
      @disableWorker = params?.disableWorker
      @workerSrc = params.workerSrc if params?.workerSrc
      @chunkSize = params.chunkSize if params?.chunkSize?
      @cryptoWorker = @_createCryptoWorker()

    _createCryptoWorker: =>
      if not @disableWorker and not Crypto._browserSupport.useWorker?
        testArray = new ArrayBuffer 8
        cryptoWorker = null
        transferable = false

        if Worker
          try
            cryptoWorker = new WebCryptoWorker @, @size, @onProgress, @workerSrc, @chunkSize
            try
              cryptoWorker.worker.postMessage
                message: 'test'
                data: testArray
              ,
                [testArray]
              # If array was correctly transferred, it becomes unusable (neutered) here
              transferable = not testArray.byteLength
            catch error
              transferable = false
              cryptoWorker.enqueue
                type: 'array'
                size: 0 # We do not want to modify totalSizeQueued with our test
                data: testArray
                message: 'ping'
                transferable: transferable

        if not cryptoWorker
          cryptoWorker = new FallbackCryptoWorker @, @size, @onProgress, @chunkSize
          Crypto._browserSupport.useWorker = false
          Crypto._browserSupport.transferable = false

        else if transferable
          Crypto._browserSupport.useWorker = true
          Crypto._browserSupport.transferable = true

        # If transferable is false, even if useWorker is set at this point
        # we need to wait for "pong" answer from worker because structured
        # copy may not work

      else
        if not @disableWorker and Crypto._browserSupport.useWorker
          cryptoWorker = new WebCryptoWorker @, @size, @onProgress, @workerSrc, @chunkSize
        else
          cryptoWorker = new FallbackCryptoWorker @, @size, @onProgress, @chunkSize

      cryptoWorker

    update: (data, callback) =>
      throw new Error "No data given" if not data
      callback ?= ->

      assert @cryptoWorker

      params =
        message: 'update'
        data: data
        onDone: callback
      if params.data instanceof Blob
        params.type = 'blob'
        params.size = params.data.size
       else
        params.type = 'array'
        params.size = params.data.byteLength

      @cryptoWorker.enqueue params

    finalize: (callback) =>
      throw new Error "No callback given" if not callback

      assert @cryptoWorker

      params =
        message: 'finalize'
        onDone: callback
      @cryptoWorker.enqueue params

    _destroy: =>
      delete @cryptoWorker.worker if @cryptoWorker
      delete @cryptoWorker

    _switchToFallbackWorker: =>
      @cryptoWorker.worker.terminate()
      delete @cryptoWorker.worker

      fallbackWorker = new FallbackCryptoWorker @, @cryptoWorker.size, @onProgress, @chunkSize
      fallbackWorker.enqueue @cryptoWorker.queue
      @cryptoWorker = fallbackWorker

class BaseCryptoWorker
  constructor: (@instance, @size, @onProgress, @chunkSize) ->
    @chunkStart = 0
    @busy = false
    @queue = []
    @current = null
    @totalSizeQueued = 0
    @totalSizeProcessed = 0

    @handler =
      chunkDone: =>
        progress = @totalSizeProcessed / (@size or @totalSizeQueued)
        @onProgress progress
        @busy = false
        @nextInQueue()

      done: (result) =>
        @current?.onDone? null, result

      error: (error) =>
        @current?.onDone? error, null

      pong: (params) =>
        if params.data instanceof ArrayBuffer
          Crypto._browserSupport.useWorker = true
          @busy = false
          @nextInQueue()
        else
          Crypto._browserSupport.useWorker = false
          @instance._switchToFallbackWorker()

  enqueue: (params) =>
    if _.isArray params
      @enqueue item for item in params
    else
      @totalSizeQueued += params.size or 0
      @queue.push params
    @nextInQueue()

  nextInQueue: =>
    return if @busy
    @busy = true

    # Check if current chunk is processed completely
    if @current and @chunkStart >= @current.size
      @handler.done
        error: null,
        result: null
      @current = null

    if not @current
      @chunkStart = 0
      @current = @queue.shift() or null
      if not @current
        @busy = false
        return

    if @current.message is 'finalize'
      @finalize()
      return

    if @current.message is 'ping'
      @worker.postMessage
        message: 'ping'
        data: @current.data
      return

    # Read next chunk (or part of chunk)
    start = @chunkStart
    end = start + @chunkSize
    end = @current.size if end > @current.size
    @chunkStart = end
    chunk = @current.data.slice start, end
    @totalSizeProcessed += end - start
    if @current.type is 'blob'
      @readBlob chunk
    else
      @processChunk chunk

  readBlob: (blob) =>
    reader = new FileReader()
    reader.onload = (event) =>
      @processChunk reader.result
    reader.readAsArrayBuffer blob

  processChunk: (chunk) ->
    throw new Error "Not implemented!"

  finalize: (params) ->
    throw new Error "Not implemented!"

  destroy: ->
    throw new Error "Not implemented!"

class WebCryptoWorker extends BaseCryptoWorker
  constructor: (instance, size, onProgress, workerSrc, chunkSize) ->
    super instance, size, onProgress, chunkSize

    @worker = new Worker workerSrc

    @worker.onmessage = (event) =>
      data = event.data.data
      message = event.data.message
      @handler[message] data

    @worker.onerror = (error) =>
      @handler.error error
      @destroy()

  processChunk: (chunk) =>
    message =
      message: 'update'
      chunk: chunk
    if @transferable
      @worker.postMessage message, [chunk]
    else
      @worker.postMessage message

  finalize: =>
    @worker.postMessage
      message: 'finalize'

  destroy: =>
    @worker.terminate()
    @instance._destroy()

class FallbackCryptoWorker extends BaseCryptoWorker
  constructor: (instance, size, onProgress, chunkSize) ->
    super instance, size, onProgress, chunkSize

    @hash = new Digest.SHA256

  _bin2hex: (array) =>
    hexTab = '0123456789abcdef'
    str = ''
    for a in array
      str += hexTab.charAt((a >>> 4) & 0xF) + hexTab.charAt(a & 0xF)
    str

  processChunk: (chunk) =>
    try
      @hash.update chunk
    catch error
      @handler.error error
      @destroy()
      return
    @handler.chunkDone()

  finalize: =>
    try
      binaryData = @hash.finalize()
      sha256 = @_bin2hex new Uint8Array binaryData
      @handler.done sha256
    catch error
      @handler.error error

  destroy: =>
    @instance._destroy()
