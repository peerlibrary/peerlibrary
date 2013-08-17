Template.index.searchActive = ->
  Session.get 'searchActive'

Template.indexSearchInput.publications = ->
  searchResult = SearchResults.findOne
    query: null

  if not searchResult
    return 0
  else
    return searchResult.countPublications

Template.indexSearchInput.people = ->
  searchResult = SearchResults.findOne
    query: null

  if not searchResult
    return 0
  else
    return searchResult.countPeople

# TODO: Improve this
searchOn = @searchOn

Template.indexSearchInput.events =
  'keyup .search-input': (e) ->
    searchOn()
    Session.set 'currentSearchQuery', $('.search-input').val()
    $('#title').val $('.search-input').val()
