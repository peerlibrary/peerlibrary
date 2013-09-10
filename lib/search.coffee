SearchResults = new Meteor.Collection 'SearchResults', transform: (doc) => new SearchResult doc

class SearchResult extends @Document
  # query: query object or string as provided by the client (or null for a document counting available content to search over)
  # countPublications: number of publications in the results for the query
  # countPersons: number of people in the results for the query

@SearchResults = SearchResults
@SearchResult = SearchResult
