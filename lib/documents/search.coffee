class @SearchResult extends Document
  # query: query object or string as provided by the client
  # countPublications: number of publications in the results for the query
  # countPersons: number of people in the results for the query

  @Meta
    name: 'SearchResult'
    # We use local collection on the server side because we do not really want to store this into the database
    collection: if Meteor.isServer then null else 'SearchResults'
