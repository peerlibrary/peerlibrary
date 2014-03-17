@generalQueryChange = (newQuery) ->
  oldQuery = Session.get 'currentSearchQuery'
  if "#{ oldQuery }" is "#{ newQuery }" # Make sure we compare primitive strings
    return

  # TODO: Add fields from the sidebar
  Session.set 'currentSearchQuery', newQuery
  Session.set 'currentSearchLimit', INITIAL_SEARCH_LIMIT

@structuredQueryChange = (newQuery) ->
  oldQuery = Session.get 'currentSearchQuery'
  if "#{ oldQuery }" is "#{ newQuery.general }" # Make sure we compare primitive strings
    return

  # TODO: Add other fields from the sidebar
  Session.set 'currentSearchQuery', newQuery.general
  Session.set 'currentSearchLimit', INITIAL_SEARCH_LIMIT
