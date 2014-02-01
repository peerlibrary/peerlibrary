Deps.autorun ->
  if Session.get 'indexActive'
    Meteor.subscribe 'statistics'

Template.indexStatistics.publications = ->
  Statistics.findOne()?.countPublications or 0

Template.indexStatistics.persons = ->
  Statistics.findOne()?.countPersons or 0

Template.index.searchActive = ->
  Session.get 'searchActive'

Template.indexMain.created = ->
  @_background = new Background()
  @_backgroundRendered = false

  $(window).on 'resize.background', @_background.resize

Template.indexMain.rendered = ->
  return if @_backgroundRendered
  @_backgroundRendered = true

  Deps.nonreactive =>
    $(@findAll '.landing').append @_background.render()

Template.indexMain.destroyed = ->
  $(window).off '.background'

  @_background.destroy()
  @_background = null
  @_backgroundRendered = false
