@simpleQueryChange = (newQuery) ->
  oldQuery = Session.get 'currentSearchQuery'
  if "#{ oldQuery }" is "#{ newQuery }" # Make sure we compare primitive strings
    return

  # TODO: Parse simple query
  Session.set 'currentSearchQuery', newQuery
  Session.set 'currentSearchLimit', INITIAL_SEARCH_LIMIT

@structuredQueryChange = (newQuery) ->
  oldQuery = Session.get 'currentSearchQuery'

  # TODO: Reconstruct simple query from structured query
  if "#{ oldQuery }" is "#{ newQuery.title }" # Make sure we compare primitive strings
    return

  Session.set 'currentSearchQuery', newQuery.title
  Session.set 'currentSearchLimit', INITIAL_SEARCH_LIMIT
