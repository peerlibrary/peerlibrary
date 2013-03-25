do -> # To not pollute the namespace
  Template.index.created = ->
    Session.set 'searchActive', false

  Template.index.rendered = ->
    $('.search-input').focus();