Crypto =
  SHA256: class
    # params:
    #   onProgress(progress): progress callback function (optional)
    #     progress: float, between 0 and 1 (inclusive), if it can be computed
    #   size: complete file size, if known (optional)
    constructor: (params) ->
      @onProgress = params?.onProgress or ->
      @size = params?.size

    # data: chunk of data to be added for hash computation (required)
    # callback(error): callback function (optional)
    #   error: error or null if there is no error
    update: (data, callback) =>
      throw new Error "Not implemented"

    # callback(error, sha256): callback function (required on client)
    #   error: error or null if there is no error
    #   sha256: result as a hex string
    finalize: (callback) =>
      throw new Error "Not implemented"
