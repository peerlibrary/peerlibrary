# TODO: Also do something on normal exit, so that publications which are being processed at the moment of exit have some consistent state

currentlyProcessedPublicationId = null

@currentlyProcessingPublication = (id) ->
  throw new Error "A publication is already being processed, only one publication can be processed at the time" if currentlyProcessedPublicationId
  currentlyProcessedPublicationId = id

SegfaultHandler.registerHandler (stack, signal, address) ->
  # TODO: Should we log also errors outside publication processing?
  return unless currentlyProcessedPublicationId

  Publications.update currentlyProcessedPublicationId,
    $set:
      processError:
        # TODO: Add a timestamp
        error: "Received SIGSEGV/SIGBUS (#{ signal }) for address 0x#{ address.toString(16) }"
        stack: stack.join('\n')
