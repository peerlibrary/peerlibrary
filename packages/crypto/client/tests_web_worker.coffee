globals = @

# Web worker tests

Tinytest.addAsync '[WebWorker] Testing support', (test, onComplete) ->
  globals.queue.push () ->
    globals.createHash()
    test.equal globals.hash.worker.constructor.name, 'WebWorker',
               'Fallback worker not allowed in web worker test'
    globals.hash.update globals.pdf, (error, result) ->
      test.equal error, null
      test.equal globals.hash.worker.constructor.name, 'WebWorker',
                 'Web worker is not supported!'
      onComplete()
  globals.processQueue()
