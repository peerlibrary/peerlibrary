Template.index.searchActive = ->
  Session.get 'searchActive'

Template.presentation.created = ->
  $('.landing').height($(window).height() - 900)