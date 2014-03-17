Template.header.events =
  'click .top-menu .search': (e, template) ->
    # Only if focused on no-index header
    if Template.header.noIndexHeader()
      Session.set 'searchFocused', true

    return # Make sure CoffeeScript does not return anything

  'click .search-input': (e, template) ->
    # Only if focused on no-index header
    if Template.header.noIndexHeader()
      Session.set 'searchFocused', true

    return # Make sure CoffeeScript does not return anything

  'click .search-button': (e, template) ->
    Session.set 'searchActive', true
    generalQueryChange $(template.findAll '.search-input').val()

    return # Make sure CoffeeScript does not return anything

  'blur .search-input': (e, template) ->
    Session.set 'searchFocused', false
    generalQueryChange $(template.findAll '.search-input').val()

    return # Make sure CoffeeScript does not return anything

  'change .search-input': (e, template) ->
    Meteor.Router.toNew Meteor.Router.indexPath() unless Session.get 'indexActive'
    Session.set 'searchActive', true
    Session.set 'searchFocused', true
    generalQueryChange $(template.findAll '.search-input').val()

    return # Make sure CoffeeScript does not return anything

  'keyup .search-input': (e, template) ->
    val = $(template.findAll '.search-input').val()

    # If user focused with tab or pressed some other non-content key we don't want to activate the search
    if val
      Meteor.Router.toNew Meteor.Router.indexPath() unless Session.get 'indexActive'
      Session.set 'searchActive', true
      Session.set 'searchFocused', true

    generalQueryChange val

    return # Make sure CoffeeScript does not return anything

  'paste .search-input': (e, template) ->
    Meteor.Router.toNew Meteor.Router.indexPath() unless Session.get 'indexActive'
    Session.set 'searchActive', true
    Session.set 'searchFocused', true
    generalQueryChange $(template.findAll '.search-input').val()

    return # Make sure CoffeeScript does not return anything

  'cut .search-input': (e, template) ->
    Session.set 'searchActive', true
    Session.set 'searchFocused', true
    generalQueryChange $(template.findAll '.search-input').val()

    return # Make sure CoffeeScript does not return anything

  'submit #search': (e, template) ->
    e.preventDefault()
    # If search is empty and user presses enter (submits the form), we should activate - maybe user wants structured query form
    Session.set 'searchActive', true
    Session.set 'searchFocused', true
    generalQueryChange $(template.findAll '.search-input').val()

    return # Make sure CoffeeScript does not return anything

Template.header.development = ->
  'development' unless Meteor.settings?.public?.production

Template.header.indexHeader = ->
  'index-header' if Template.footer.indexFooter()

Template.header.noIndexHeader = ->
  'no-index-header' if not Template.header.indexHeader()

Template.searchInput.searchFocused = ->
  'search-focused' if Session.get 'searchFocused'

Template.searchInput.rendered = ->
  # We make sure search input is focused if we know it should be focused (to make sure focus is retained between redraws)
  # Additionally, HTML5 autofocus does not work properly when routing back to / after initial load, so we focus if we are displaying index header
  # Don't try to focus if reset password is in progress
  if (Session.get('searchFocused') or Template.header.indexHeader()) and not Accounts._loginButtonsSession.get 'resetPasswordToken'
    $(@findAll '.search-input').focus()

Template.searchInput.indexHeader = Template.header.indexHeader

Template.searchInput.noIndexHeader = Template.header.noIndexHeader

Template.searchInput.searchInvitation = ->
  if Session.get 'currentSearchQuery'
    Session.get 'currentSearchQuery'
  else
    "Search academic publications and people"

Template.searchInput.development = Template.header.development

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