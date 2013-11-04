Template.header.events =
  'click .top-menu .search': (e, template) ->
    # Only if focused on no-index header
    if Template.header.noIndexHeader()
      Session.set 'searchFocused', true

  'click .search-input': (e, template) ->
    # Only if focused on no-index header
    if Template.header.noIndexHeader()
      Session.set 'searchFocused', true

  'click .search-button': (e, template) ->
    Session.set 'searchActive', true
    naturalQueryChange $(template.findAll '.search-input').val()

  'blur .search-input': (e, template) ->
    Session.set 'searchFocused', false
    naturalQueryChange $(template.findAll '.search-input').val()

  'change .search-input': (e, template) ->
    Session.set 'searchActive', true
    Session.set 'searchFocused', true
    naturalQueryChange $(template.findAll '.search-input').val()

  'keyup .search-input': (e, template) ->
    val = $(template.findAll '.search-input').val()
    # If user focused with tab or pressed some other non-content key we don't want to activate the search
    Session.set 'searchActive', true if val
    Session.set 'searchFocused', true
    naturalQueryChange val

  'paste .search-input': (e, template) ->
    Session.set 'searchActive', true
    Session.set 'searchFocused', true
    naturalQueryChange $(template.findAll '.search-input').val()

  'cut .search-input': (e, template) ->
    Session.set 'searchActive', true
    Session.set 'searchFocused', true
    naturalQueryChange $(template.findAll '.search-input').val()

  'submit #search': (e, template) ->
    e.preventDefault()
    # If search is empty and user presses enter (submits the form), we should activate - maybe user wants structured query form
    Session.set 'searchActive', true
    Session.set 'searchFocused', true
    naturalQueryChange $(template.findAll '.search-input').val()

Template.header.development = ->
  'development' unless Meteor.settings?.public?.production

Template.header.indexHeader = ->
  'index-header' if Template.footer.indexFooter()

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
  # We make sure search input is focused if we know it should be focused (to make sure focus is retained between redraws)
  # Additionally, HTML5 autofocus does not work properly when routing back to / after initial load, so we focus if we are displaying index header
  if Session.get('searchFocused') or Template.header.indexHeader()
    $(@findAll '.search-input').focus()

Template.searchInput.indexHeader = Template.header.indexHeader

Template.searchInput.noIndexHeader = Template.header.noIndexHeader

Template.searchInput.searchInvitation = ->
  if Session.get 'currentSearchQuery'
    Session.get 'currentSearchQuery'
  else
    "Search scientific publications and people"

Deps.autorun ->
  $('.search-input').val(Session.get 'currentSearchQuery')

Template.progressBar.progress = ->
  100 * Session.get 'currentPublicationProgress'

progressHide = null
Deps.autorun ->
  progress = Session.get 'currentPublicationProgress'

  if progress != 1.0
    Meteor.clearTimeout progressHide if progressHide
    progressHide = null
    return

  return if progressHide

  progressHide = Meteor.setTimeout ->
    Session.set 'currentPublicationProgress', null
    progressHide = null
  , 250

Accounts.ui.config
  passwordSignupFields: 'USERNAME_AND_EMAIL'