@generalQueryChangeLock = 0
@structuredQueryChangeLock = 0

@generalQueryChange = (newQuery) ->
  oldQuery = Session.get 'currentSearchQuery'
  if "#{ oldQuery }" is "#{ newQuery }" # Make sure we compare primitive strings
    return

  # We increase the counter to signal that general query invoked the change
  generalQueryChangeLock++
  Tracker.afterFlush ->
    Meteor.setTimeout ->
      generalQueryChangeLock--
      assert generalQueryChangeLock >= 0
    , 100 # ms after the flush we unlock

  # TODO: Add fields from the sidebar
  Session.set 'currentSearchQuery', newQuery
  Session.set 'currentSearchLimit', INITIAL_SEARCH_LIMIT

@structuredQueryChange = (newQuery) ->
  oldQuery = Session.get 'currentSearchQuery'
  if "#{ oldQuery }" is "#{ newQuery.general }" # Make sure we compare primitive strings
    return

  # We increase the counter to signal that structured query invoked the change
  structuredQueryChangeLock++
  Tracker.afterFlush ->
    Meteor.setTimeout ->
      structuredQueryChangeLock--
      assert structuredQueryChangeLock >= 0
    , 100 # ms after the flush we unlock

  # TODO: Add other fields from the sidebar
  Session.set 'currentSearchQuery', newQuery.general
  Session.set 'currentSearchLimit', INITIAL_SEARCH_LIMIT
