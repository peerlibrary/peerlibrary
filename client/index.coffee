do -> # To not pollute the namespace
  Template.index.created = ->
    Session.set 'searchActive', false

  Template.index.rendered = ->
    $('.search-input').focus();

  Template.index.events =
    'click .search-link': (e) ->
      searchOn()
    'click .search': (e) ->
      if not $(e.target).is 'input'
        searchOff()
    'click .search-input': (e) ->
      if not Session.get 'searchActive'
        searchOn()
    'keydown': (e) ->
      if not Session.get 'searchActive'
        char = String.fromCharCode e.which
        if char.match(/\w/) and not e.ctrlKey
          searchOn()
    'keyup': (e) ->
      if e.which is 27
        searchOff()
    'keypress input': (e) ->
      if e.which is 13
        e.preventDefault()
        handleRegister e

  searchOn = ->
    Session.set 'searchActive', true
    $('.search').fadeIn 250
    $('.search-input').focus()
    $('.search-input').animate
      width: '1000px'
      , 250

  searchOff = ->
    Session.set 'searchActive', false
    $('.search').fadeOut 250
    $('.search-input').focus()
    $('.search-input').val ''
    $('.search-input').animate
      width: '630px'
      , 250