# TODO: How to properly find out the location of this? And know the query string value?
WORKER_SRC = '/packages/crypto/assets/worker.js'
CHUNK_SIZE = 128 * 1024 # bytes

Crypto =
  _browserSupport:
    useWorker: null
    transferable: null

  SHA256: class extends Crypto.SHA256
    # Defaults
    disableWorker: null
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
      @disableWorker = params.disableWorker if params?.disableWorker?
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
          catch error
            # There was an error creating a worker, but disableWorker is
            # explicitly set to false, so fallback is forbidden, let's rethrow
            throw error if @disableWorker is false

        if not cryptoWorker
          cryptoWorker = new FallbackCryptoWorker @, @size, @onProgress, @chunkSize
          Crypto._browserSupport.useWorker = false
          Crypto._browserSupport.transferable = false

        else if transferable
          Crypto._browserSupport.useWorker = true
          Crypto._browserSupport.transferable = true

        else
          # If transferable is false, we need to wait for "pong" answer
          # from worker because structured copy may not work
          Crypto._browserSupport.transferable = false

      else
        # Or is disableWorker not set and we can use a web worker, or disableWorker is explicitly set to false
        if (not @disableWorker? and Crypto._browserSupport.useWorker) or @disableWorker is false
          cryptoWorker = new WebCryptoWorker @, @size, @onProgress, @workerSrc, @chunkSize
        else
          cryptoWorker = new FallbackCryptoWorker @, @size, @onProgress, @chunkSize

      cryptoWorker

    update: (data, callback) =>
      throw new Error "No data given" if not data

      unless @cryptoWorker
        if callback
          return callback new Error "Reusing consumed instance"
        else
          throw new Error "Reusing consumed instance"

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

      @cryptoWorker.enqueue params

    finalize: (callback) =>
      throw new Error "No callback given" if not callback

      return callback new Error "Reusing consumed instance" unless @cryptoWorker

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

      queue = @cryptoWorker.queue
      @cryptoWorker = new FallbackCryptoWorker @, @size, @onProgress, @chunkSize
      @cryptoWorker.addQueue queue

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
        @destroy()
        @current?.onDone? null, result

      error: (error) =>
        @destroy()
        @current?.onDone? error, null

      pong: (params) =>
        Crypto._browserSupport.useWorker = params.data instanceof ArrayBuffer
        # Or we can use a web worker, or disableWorker is explicitly set to false
        if Crypto._browserSupport.useWorker or @instance.disableWorker is false
          @busy = false
          @nextInQueue()
        else
          @instance._switchToFallbackWorker()

  enqueue: (params) =>
    @totalSizeQueued += params.size or 0
    @queue.push params
    @nextInQueue()

  addQueue: (queue) =>
    @totalSizeQueued += item.size or 0 for item in queue
    @queue = @queue.concat queue
    @nextInQueue()

  nextInQueue: =>
    return if @busy
    @busy = true

    # Check if current chunk is processed completely
    if @current and @chunkStart >= @current.size
      @current.onDone?()
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
      @ping @current.data
     return

    assert.equal @current.message, 'update'

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

  ping: (data) ->
    throw new Error "Not implemented!"

  destroy: ->
    throw new Error "Not implemented!"

class WebCryptoWorker extends BaseCryptoWorker
  constructor: (instance, size, onProgress, workerSrc, chunkSize) ->
    super instance, size, onProgress, chunkSize

    @worker = new Worker workerSrc

    @worker.addEventListener 'message', (event) =>
      data = event.data.data
      message = event.data.message
      @handler[message] data
    , false

    @worker.addEventListener 'error', (error) =>
      @handler.error error
    , false

  processChunk: (chunk) =>
    message =
      message: 'update'
      chunk: chunk
    if Crypto._browserSupport.transferable
      @worker.postMessage message, [chunk]
    else
      @worker.postMessage message

  finalize: =>
    @worker.postMessage
      message: 'finalize'

  ping: (data) =>
    @worker.postMessage
      message: 'ping'
      data: data

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
      return @handler.error error

    @handler.chunkDone()

  finalize: =>
    try
      binaryData = @hash.finalize()
      sha256 = @_bin2hex new Uint8Array binaryData
    catch error
      return @handler.error error

    @handler.done sha256

  destroy: =>
    @instance._destroy()
