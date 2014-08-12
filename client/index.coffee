Deps.autorun ->
  if Session.get 'indexActive'
    Meteor.subscribe 'statistics'
    Meteor.subscribe 'latest-blog-post'

Template.indexStatistics.publications = ->
  Statistics.documents.findOne()?.countPublications or 0

Template.indexStatistics.persons = ->
  Statistics.documents.findOne()?.countPersons or 0

Template.indexStatistics.highlights = ->
  Statistics.documents.findOne()?.countHighlights or 0

Template.indexStatistics.annotations = ->
  Statistics.documents.findOne()?.countAnnotations or 0

Template.indexStatistics.groups = ->
  Statistics.documents.findOne()?.countGroups or 0

Template.indexStatistics.collections = ->
  Statistics.documents.findOne()?.countCollections or 0

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

Template.indexLatestBlogPost.latestBlogPost = ->
  BlogPost.documents.findOne()

Template.indexLatestBlogPost.blogPostsCount = ->
  Statistics.documents.findOne()?.countBlogPosts or 0

Template.indexLatestBlogPost.blogUrl = ->
  Meteor.settings?.public?.blogUrl

Meteor.startup ->
  Session.setDefault 'backgroundPaused', false

Template.backgroundPause.rendered = ->
  $(@find 'button').tooltip
    position:
      my: 'left center'
      at: 'right+15 center'
    show: 200
    hide: 200
    tooltipClass: 'right'

Template.backgroundPause.events
  'click button': (event, template) ->
    $(template.find 'button').tooltip('destroy')
    Session.set('backgroundPaused', not Session.get 'backgroundPaused')
    return # Make sure CoffeeScript does not return anything

Template.backgroundPause.backgroundPaused = ->
  Session.get 'backgroundPaused'
