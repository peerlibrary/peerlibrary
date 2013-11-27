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

Template.indexMain.created = ->
  @_background = new Background
  @_backgroundRendered = false

  $(window).on 'resize.background', @_background.resize

Template.indexMain.rendered = ->
  return if @_backgroundRendered

  Deps.nonreactive =>
    $(@find '.landing').append @_background.render()

    @_backgroundRendered = true

Template.indexMain.destroyed = ->
  $(window).off 'resize.background'

  @_background.destroy()
  @_background = null
  @_backgroundRendered = false
