Template.index.created = ->
  Session.set 'searchActive', false

Template.index.rendered = ->
  $('.search-input').focus()

Template.index.publications = ->
  if not Session.get 'currentSearchQuery'
    return

  Publications.find
    'searchResult.query': Session.get 'currentSearchQuery'
  ,
    sort:
      'searchResult.order': 1
    limit: Session.get 'currentSearchLimit'
