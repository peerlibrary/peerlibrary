Template.header.events =
  'click .top-menu .search': (e) ->
    searchOn()

  'click .search-input': (e) ->
    if not Session.get 'searchActive'
      searchOn()

  'click .search-button': ->

  'blur .search-input': ->
    searchOff()

  'keyup': (e) ->
    if $('.search-input').is(':focus')
      Session.set 'currentSearchQuery', $('.search-input').val()

  'submit #search': (e) ->
    e.preventDefault()

searchOn = ->
  Session.set 'searchActive', true
  $('.top-menu .search').addClass('selected')
  $('.search-input').focus()
  $('li.explore').hide()

searchOff = ->
  Session.set 'searchActive', false
  Session.set 'currentSearchLimit', 5
  $('.top-menu .search').removeClass('selected')
  $('li.explore').fadeIn 200
  if $('.search-input').val()
    $('.top-menu .search .label').html('<i class="icon-search"></i> ' + $('.search-input').val().substring(0,55) + ' <span class="cursor"></span>')
  else
    $('.top-menu .search .label').html('<i class="icon-search"></i> Search for publications, authors and keywords <span class="cursor"></span>')