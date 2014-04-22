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
    for name, route of namedRoutes
      params = {}
      if route.match path, null, params
        return name: name, route: route, params: params
