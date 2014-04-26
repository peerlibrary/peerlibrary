if Meteor.isServer
  namedRoutes = {}

  # We override Meteor.Router.add with our own function so that same code
  # which  we run on the client side we can reuse on the server side.
  # Code is based on the original Meteor.Router.add client-side code.
  Meteor.Router.add = (path, endpoint) ->
    if _.isObject(path) and not _.isRegExp(path)
      return _.each path, (endpoint, p) =>
        @add p, endpoint

    # '/foo' -> 'bar' <==> '/foo' => {to: 'bar'}
    endpoint = to: endpoint if not _.isObject(endpoint) or _.isFunction(endpoint)

    # Route name defaults to template name (unless it's functional)
    endpoint.as = endpoint.to if not endpoint.as and _.isString(endpoint.to)

    return unless endpoint.as

    return unless endpoint.documentId

    namedRoutes[endpoint.as] = new Meteor.Router.Route path
    namedRoutes[endpoint.as].documentId = endpoint.documentId

@routeResolve = (path) ->
  for name, route of (if Meteor.isServer then namedRoutes else Meteor.Router.namedRoutes)
    params = {}
    if route.match path, null, params
      return name: name, route: route, params: params

startsWith = (string, start) ->
  string.lastIndexOf(start, 0) is 0

localPath = (path) ->
  resolved = routeResolve path
  # We extract only those paths for which a route has documentId configured
  return unless resolved?.route?.documentId
  # And name set
  return unless resolved.name

  if _.isFunction resolved.route.documentId
    referenceId = resolved.route.documentId resolved.params
  else
    referenceId = resolved.params[resolved.route.documentId]

  return unless referenceId

  try
    check referenceId, DocumentId
  catch error
    # Not a valid document ID
    return

  referenceName: resolved.name
  referenceId: referenceId

@parseURL = (href) ->
  return unless href

  return localPath href if href[0] is '/'

  href = UrlUtils.normalize href if Meteor.isServer

  rootUrl = Meteor.absoluteUrl()
  return localPath href.substring rootUrl.length - 1 if startsWith href, rootUrl

  # When doing local development, we can use both localhost or 127.0.0.1, so let's check both
  rootUrl = Meteor.absoluteUrl replaceLocalhost: true
  return localPath href.substring rootUrl.length - 1 if startsWith href, rootUrl

  if Meteor.isServer
    try
      urlId = Url.documents.insert
        url: href
    catch error
      if error.name isnt 'MongoError'
        throw error
      # TODO: Improve when https://jira.mongodb.org/browse/SERVER-3069
      if /E11000 duplicate key error index:.*Urls\.\$url/.test error.err
        # This should then always succeed
        # No need for requireReadAccessSelector because urls are internal
        urlId = Url.documents.findOne({url: href}, {fields: _id: 1})._id
      else
        throw error

    referenceName: 'url'
    referenceId: urlId
  else
    referenceName: 'external'
    referenceId: href
