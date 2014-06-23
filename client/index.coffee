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

Template.indexBlogPosts.postUrl = ->
  BlogPost.documents.findOne()?.postUrl

Template.indexBlogPosts.totalPostCount = ->
  BlogPost.documents.findOne()?.postNumber

Template.indexBlogPosts.postsExist = ->
  return !!BlogPost.documents.findOne()
