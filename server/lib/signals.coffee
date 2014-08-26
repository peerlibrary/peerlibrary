# TODO: Also do something on normal exit, so that publications which are being processed at the moment of exit have some consistent state

currentlyProcessingPublicationJob = null

# We force only one publication to be processed at a time
# so that we know with which job to associate the signal with
@currentlyProcessingPublication = (job) ->
  throw new Error "A publication is already being processed, only one publication can be processed at the time" if currentlyProcessingPublicationJob and job
  currentlyProcessingPublicationJob = job

SegfaultHandler.registerHandler (stack, signal, address) ->
  message = "Received SIGSEGV/SIGBUS (#{ signal }) for address 0x#{ address.toString(16) }"
  stack = stack.join '\n'
  Log.error "#{ message }\n#{ stack }"

  # TODO: Should we log also errors outside publication processing?
  return unless currentlyProcessingPublicationJob

  currentlyProcessingPublicationJob.getQueueJob().fail EJSON.toJSONValue(value: message, stack: stack),
    fatal: true
