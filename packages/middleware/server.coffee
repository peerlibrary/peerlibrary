Fiber = Npm.require 'fibers'
savedYield = Fiber.yield

globals = @

# When inside Meteor._noYieldsAllowed Fiber.yield is overridden with
# a function which throws an exception, so is not savedYield anymore.
# Afterwards Fiber.yield is restored back to savedYield.
isInsideNoYieldsAllowed = ->
  Fiber.yield isnt savedYield

class MiddlewarePublish
  constructor: (@publish) ->
    # We store those methods at construction time because
    # we override them later on publish object.
    @_publishAdded = @publish.added.bind @publish
    @_publishChanged = @publish.changed.bind @publish
    @_publishRemoved = @publish.removed.bind @publish
    @_publishReady = @publish.ready.bind @publish
    @_publishStop = @publish.stop.bind @publish
    @_publishError = @publish.error.bind @publish

    @userId = @publish.userId

  added: (args...) =>
    @_publishAdded args...

  changed: (args...) =>
    @_publishChanged args...

  removed: (args...) =>
    @_publishRemoved args...

  ready: (args...) =>
    @_publishReady args...

  stop: (args...) =>
    @_publishStop args...

  error: (args...) =>
    @_publishError args...

  # The following methods we do not override, so
  # we can access them directly here.

  onStop: (args...) =>
    @publish.onStop args...

  connection: (args...) =>
    @publish.connection args...

  params: (args...) =>
    @publish.params()

class globals.PublishEndpoint
  constructor: (@options, @publishFunction) ->
    # To pass null (autopublish) or string directly for name
    if @options is null or _.isString @options
      @options =
        name: @options

    @middlewares = []

    self = @

    Meteor.publish @options.name, ->
      publish = @

      publish.params = ->
        @_params

      self.publish self.middlewares, publish

  publish: (middlewares, publish) =>
    if middlewares.length
      latestMiddleware = middlewares[middlewares.length - 1]
      otherMiddlewares = middlewares[0...middlewares.length - 1]

      midlewarePublish = new MiddlewarePublish publish

      publish.added = (collection, id, fields) ->
        latestMiddleware.added midlewarePublish, collection, id, fields

      publish.changed = (collection, id, fields) ->
        latestMiddleware.changed midlewarePublish, collection, id, fields

      publishRemoved = publish.removed
      publish.removed = (collection, id) ->
        # When unsubscribing, Meteor removes all documents so this callback is called
        # inside Meteor._noYieldsAllowed which means inside the callback no function
        # which calls yield can be called. Because this is often not true, in that
        # special case we are not going through middlewares but are directly calling
        # original removed callback.
        if isInsideNoYieldsAllowed()
          publishRemoved.call publish, collection, id
        else
          latestMiddleware.removed midlewarePublish, collection, id

      publish.ready = ->
        latestMiddleware.onReady midlewarePublish

      publish.stop = ->
        latestMiddleware.onStop midlewarePublish

      publish.error = (error) ->
        latestMiddleware.onError midlewarePublish, error

      @publish otherMiddlewares, publish
    else
      @publishFunction.apply publish, publish.params()

  use: (middleware) =>
    throw new Error "Middleware '#{ middleware }' is not an instance of a PublishMiddleware class" unless middleware instanceof PublishMiddleware

    @middlewares.push middleware

class globals.PublishMiddleware
  added: (publish, collection, id, fields) =>
    publish.added collection, id, fields

  changed: (publish, collection, id, fields) =>
    publish.changed collection, id, fields

  removed: (publish, collection, id) =>
    publish.removed collection, id

  onReady: (publish) =>
    publish.ready()

  onStop: (publish) =>
    publish.stop()

  onError: (publish, error) =>
    publish.error error

PublishEndpoint = globals.PublishEndpoint
PublishMiddleware = globals.PublishMiddleware
