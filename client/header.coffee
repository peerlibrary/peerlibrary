Template.header.events =
  'click .top-menu .search': (e, template) ->
    Session.set 'searchActive', true
    Session.set 'searchFocused', true

  'click .search-input': (e, template) ->
    Session.set 'searchActive', true
    Session.set 'searchFocused', true

  'click .search-button': (e, template) ->
    Session.set 'currentSearchQuery', $(template.findAll '.search-input').val()

  'blur .search-input': (e, template) ->
    Session.set 'searchFocused', false
    Session.set 'currentSearchQuery', $(template.findAll '.search-input').val()

  'change .search-input': (e, template) ->
    Session.set 'currentSearchQuery', $(template.findAll '.search-input').val()

  'keyup .search-input': (e, template) ->
    Session.set 'currentSearchQuery', $(template.findAll '.search-input').val()

  'submit #search': (e, template) ->
    e.preventDefault()

Template.header.development = ->
  'development' unless Meteor.settings?.public?.production

Template.header.indexHeader = ->
  'index-header' if Session.get('indexActive') and Session.get('indexHeader') and not Session.get('searchActive')

Template.header.noIndexHeader = ->
  'no-index-header' if not Template.header.indexHeader()

Template.header.created = ->
  $(window).on 'scroll.header', ->
    Session.set 'indexHeader', $(window).scrollTop() < $(window).height()

Template.header.destroyed = ->
  $(window).off 'scroll.header'

Template.searchInvitation.indexHeader = Template.header.indexHeader

Template.searchInvitation.publications = ->
  searchResult = SearchResults.findOne
    query: null

  if not searchResult
    return 0
  else
    return searchResult.countPublications

Template.searchInvitation.people = ->
  searchResult = SearchResults.findOne
    query: null

  if not searchResult
    return 0
  else
    return searchResult.countPeople

Template.searchInvitation.currentSearchQuery = ->
  (Session.get('currentSearchQuery') or '').substring(0, 55)

Template.searchInput.searchFocused = ->
  'search-focused' if Session.get 'searchFocused'

Template.searchInput.rendered = ->
  if Session.get 'searchFocused'
    $(@findAll '.search-input').focus()

Deps.autorun ->
  # TODO: Parse search input and map to #title and others
  $('.search-input').add('#title').val(Session.get 'currentSearchQuery')
