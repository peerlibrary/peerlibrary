class Storage
  @url: (filename) ->
    '/pdf/' + filename

  # Client version, on server it is overriden with system's
  @_path:
    sep: '/'