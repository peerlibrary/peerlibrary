# Creates a query string for the searchPublish function that
# enables to identify the search results on the client
@searchQueryDescriptor = (filter, sort) ->
  return filter unless sort
  for sortPart in sort
    filter += ' ' + sortPart[0] + '-' + sortPart[1]

  filter
