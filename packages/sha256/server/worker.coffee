SHA256Worker =
  fromFile: (params) ->
    @initWorker params
    @worker.sendFile params

  initWorker: (params) ->
    @worker = new ServerWorker params

class ServerWorker
  constructor: (params) ->
    self = @
    @_hash = new Crypto.SHA256()

  sendFile: (params) ->
    @_hash.update(params.file)
    return @_hash.finalize()
