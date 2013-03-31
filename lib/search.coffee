SearchResults = new Meteor.Collection 'search-results', transform: (doc) -> new SearchResult doc

class SearchResult extends Document
