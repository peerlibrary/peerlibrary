Template.header.events =
  'click .top-menu .search': (e, template) ->
    Session.set 'searchActive', true
    Session.set 'searchFocused', true

  'click .search-input': (e, template) ->
    Session.set 'searchActive', true
    Session.set 'searchFocused', true

  # TODO: Parse search input and map to #title and others

  'click .search-button': (e, template) ->
    naturalQueryChange $(template.findAll '.search-input').val()

  'blur .search-input': (e, template) ->
    Session.set 'searchFocused', false
    naturalQueryChange $(template.findAll '.search-input').val()

  'change .search-input': (e, template) ->
    naturalQueryChange $(template.findAll '.search-input').val()

  'keyup .search-input': (e, template) ->
    naturalQueryChange $(template.findAll '.search-input').val()

  'paste .search-input': (e, template) ->
    naturalQueryChange $(template.findAll '.search-input').val()

  'cut .search-input': (e, template) ->
    naturalQueryChange $(template.findAll '.search-input').val()

  'submit #search': (e, template) ->
    e.preventDefault()
    naturalQueryChange $(template.findAll '.search-input').val()

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

Template.searchInput.searchFocused = ->
  'search-focused' if Session.get 'searchFocused'

Template.searchInput.rendered = ->
  if Session.get 'searchFocused'
    $(@findAll '.search-input').focus()

Template.searchInput.indexHeader = Template.header.indexHeader

Template.searchInput.noIndexHeader = Template.header.noIndexHeader

publications = ->
  searchResult = SearchResults.findOne
    query: null

  if not searchResult
    return 0
  else
    return searchResult.countPublications

people = ->
  searchResult = SearchResults.findOne
    query: null

  if not searchResult
    return 0
  else
    return searchResult.countPeople

Template.searchInput.searchInvitation = ->
  if Session.get 'currentSearchQuery'
    Session.get 'currentSearchQuery'
  else if Template.header.indexHeader()
    return "Search #{ publications() } publications and #{ people() } people"
  else
    return "Search publications and people"

Deps.autorun ->
  $('.search-input').val(Session.get 'currentSearchQuery')
