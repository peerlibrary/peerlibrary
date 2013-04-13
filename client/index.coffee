do -> # To not pollute the namespace
  Deps.autorun ->
    Session.set 'lastResultSubscribed', 0
    Session.set 'resultIds', []
    query = Session.get('currentSearchQuery')
    Meteor.subscribe 'search-results', query, ->
      Session.set 'resultIds', SearchResults.find(query: query).map (result) -> result.publicationId
      subscribeToNext(25)

  Template.index.created = ->
    Session.set 'searchActive', false

  Template.index.rendered = ->
    $('.search-input').focus()

  Template.index.publications = ->
    Publications.find
      _id:
        $in: Session.get 'resultIds'
    ,
      limit: Session.get 'lastResultSubscribed'

  Template.index.preserve ['header', '.search-bar', 'input']

  subscribeToNext = (numResults) ->
    next = Session.get('lastResultSubscribed') + numResults
    Session.set 'lastResultSubscribed', next
    Meteor.subscribe 'publications-by-ids', Session.get('resultIds').slice 0, next