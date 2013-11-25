Template.indexStatistics.publications = ->
  searchResult = SearchResults.findOne
    query: null

  searchResult?.countPublications or 0

Template.indexStatistics.persons = ->
  searchResult = SearchResults.findOne
    query: null

  searchResult?.countPersons or 0

Template.index.searchActive = ->
  Session.get 'searchActive'
