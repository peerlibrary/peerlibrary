Deps.autorun ->
  if Session.get 'indexActive'
    Meteor.subscribe 'statistics'
    Meteor.subscribe 'latest-blog-post'

Template.indexStatistics.helpers
  publications: ->
    Statistics.documents.findOne()?.countPublications or 0

  persons: ->
    Statistics.documents.findOne()?.countPersons or 0

  highlights: ->
    Statistics.documents.findOne()?.countHighlights or 0

  annotations: ->
    Statistics.documents.findOne()?.countAnnotations or 0

  groups: ->
    Statistics.documents.findOne()?.countGroups or 0

  collections: ->
    Statistics.documents.findOne()?.countCollections or 0

Template.index.helpers
  searchActive: ->
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

Template.indexLatestBlogPost.helpers
  latestBlogPost: ->
    BlogPost.documents.findOne()

  blogPostsCount: ->
    Statistics.documents.findOne()?.countBlogPosts or 0

Template.indexLatestBlogPost.helpers
  blogUrl: ->
    Meteor.settings?.public?.blogUrl

Meteor.autorun ->
  # If user is not logged in, default will be false, which user can then modify locally in Session
  backgroundPaused = !!Meteor.user()?.settings?.backgroundPaused
  Session.set 'backgroundPaused', backgroundPaused

Template.backgroundPause.events
  'click button': (event, template) ->
    backgroundPaused = not Session.get 'backgroundPaused'

    if Meteor.personId()
      # When method sets the value in the database on the server, new value will
      # be pushed back to the client and autorun will set Session accordingly
      Meteor.call 'pause-background', backgroundPaused, (error) ->
        FlashMessage.fromError error, true if error
    else
      # Otherwise modify only locally in Session
      Session.set 'backgroundPaused', backgroundPaused

    return # Make sure CoffeeScript does not return anything

Template.backgroundPauseButton.helpers
  backgroundPaused: ->
    Session.get 'backgroundPaused'

Template.backgroundPauseTooltipContent.helpers
  backgroundPaused: ->
    Session.get 'backgroundPaused'
