Template.header.events =
  'click .top-menu .search': (e) ->
    searchOn()

  'click .search-input': (e) ->
    searchOn()

  'click .search-button': ->
    Session.set 'currentSearchQuery', $('.search-input').val()

  'blur .search-input': ->
    searchOff()

  'keyup .search-input': (e) ->
    Session.set 'currentSearchQuery', $('.search-input').val()
    $('#title').val $('.search-input').val()

  'submit #search': (e) ->
    e.preventDefault()

Template.header.development = ->
  'development' unless Meteor.settings?.public?.production

Template.header.indexHeader = ->
  'index-header' if Session.get('indexHeader') and not Session.get('searchActive')

searchOn = ->
  if Session.get 'searchActive'
    return
  Session.set 'searchActive', true

  $('.top-menu .search').addClass('selected')
  $('.search-input').focus()
  $('li.explore').hide()

searchOff = ->
  if not Session.get 'searchActive'
    return
  Session.set 'searchActive', false

  $('.top-menu .search').removeClass('selected')
  $('li.explore').fadeIn 200
  if $('.search-input').val()
    $('.top-menu .search .label').html('<i class="icon-search"></i> ' + $('.search-input').val().substring(0,55) + ' <span class="cursor"></span>')
  else
    $('.top-menu .search .label').html('<i class="icon-search"></i> Search for publications and people <span class="cursor"></span>')

@searchOn = searchOn
@searchOff = searchOff
