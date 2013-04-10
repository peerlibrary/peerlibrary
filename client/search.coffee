SearchResults = new Meteor.Collection 'SearchResults', transform: (doc) -> new SearchResult doc

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
    'keypress input': (e) ->
      if e.which is 13
        e.preventDefault()
        Meteor.Router.to '/search'
        searchOff()
  
  Template.index.events searchEvents
  Template.results.events searchEvents
  Template.profile.events searchEvents

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

  return