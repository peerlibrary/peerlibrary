@SearchResults = new Meteor.Collection 'SearchResults', transform: (doc) => new @SearchResult doc

class @SearchResult extends Document
  # query: query object or string as provided by the client
  # countPublications: number of publications in the results for the query
  # countPersons: number of people in the results for the query

  # Should be a function so that we can possible resolve circual references
  @Meta =>
    collection: SearchResults
