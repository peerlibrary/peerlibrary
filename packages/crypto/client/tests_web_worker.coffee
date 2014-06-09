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
      test.isTrue Crypto.browserSupport.useWorker,
                 "Web worker is not supported!"
]
