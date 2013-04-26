do ->
  searchEvents = 
    'click .search-link': (e) ->
      searchOn()
    'click .search': (e) ->
      if not $(e.target).is 'input'
        searchOff()
    'click .search-input': (e) ->
      if not Session.get 'searchActive'
        searchOn()
    'keydown': (e) ->
      if ((not $(e.target).is 'input') or ($(e.target).is '.search-input')) and (not Session.get 'searchActive')
        char = String.fromCharCode e.which
        if char.match(/\w/) and not e.ctrlKey
          searchOn()
    'keyup': (e) ->
      if e.which is 27
        searchOff()
      if $('.search-input').val()
        Session.set 'currentSearchQuery', $('.search-input').val()
    'keypress input': (e) ->
      if e.which is 13
        e.preventDefault()
        if $('.search-input').val()
          Meteor.Router.to '/search?q=' + $('.search-input').val()
          searchOff()

  Template.index.events searchEvents
  Template.results.events searchEvents
  Template.profile.events searchEvents

  searchOn = ->
    Session.set 'searchActive', true
    $('#home .item-list').hide()
    $('.search').fadeIn 250
    $('.search-input').focus()
    $('.search-input').animate
      width: '1000px'
      , 250
    $('#home .search-bar').animate
      'margin-top': '20px'
      , 250
    $('#home .item-list').fadeIn()

  searchOff = ->
    Session.set 'searchActive', false
    Session.set 'currentSearchQuery', null
    Session.set 'currentSearchLimit', 25
    $('.search').fadeOut 250
    $('.search-input').focus()
    $('.search-input').val ''
    $('.search-input').animate
      width: '630px'
      , 250
    $('#home .search-bar').animate
      'margin-top': '20%'
      , 250
    $('#home .item-list').hide()

  return