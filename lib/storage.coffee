class @Storage
  @url: (filename) ->
    '/storage/' + filename

  # Client version, on server it is overriden with system's
  @_path:
    sep: '/'
