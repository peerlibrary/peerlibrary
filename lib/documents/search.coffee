class @SearchResult extends BaseDocument
  # name: name of the search
  # query: query identifier as provided by the client
  # count*: number of search results for the given cursor in the query (for each cursor there will be one field)

  @Meta
    name: 'SearchResult'
    # We use local collection on the server side because we do not really want to store this into the database
    collection: if Meteor.isServer then null else 'SearchResults'
