globals = @

# Web worker tests

testAsyncMulti "[WebWorker] Testing support", [
  (test, expect) ->
    globals.downloadPdf expect globals.downloadComplete
,
  (test, expect) ->
    globals.createHash()
    globals.hash.update globals.pdf, expect (error, result) ->
      test.equal error, null
      test.equal globals.hash.worker.constructor.name, 'WebWorker',
                 "Web worker is not supported!"
]
