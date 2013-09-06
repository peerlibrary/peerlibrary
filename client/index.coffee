Template.index.searchActive = ->
  Session.get 'searchActive'

Template.index.presentation.created = ->
  $('.landing').height($(window).height() - 900)