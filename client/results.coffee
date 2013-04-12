do -> # To not pollute the namespace
  Deps.autorun ->
    Session.set 'lastResultSubscribed', 0
    Session.set 'resultIds', []
    query = Session.get('currentSearchQuery')
    Meteor.subscribe 'search-results', query, ->
      Session.set 'resultIds', SearchResults.find(query: query).map (result) -> result.publicationId
      subscribeToNext(25)

  Template.results.rendered = ->
    $('.chzn').chosen()

    $('#score-range').slider
      range: true
      min: 0
      max: 100
      values: [0, 100]
      step: 10
      slide: (event, ui) ->
        $('#score').val(ui.values[ 0 ] + ' - ' + ui.values[ 1 ])

    $('#score').val($('#score-range').slider('values', 0 ) +
      ' - ' + $('#score-range').slider('values', 1 ))

    $('#date-range').slider
      range: true
      min: 0
      max: 100
      values: [0, 100]
      step: 10
      slide: (event, ui) ->
        $('#pub-date').val(ui.values[0] + ' - ' + ui.values[1])

    $('#pub-date').val($('#date-range').slider('values', 0) +
      ' - ' + $('#date-range').slider('values', 1))

    # adjust positioning of sidebar
    if $(window).width() < 1140
      $(".search-tools").css position: "absolute"
    $(window).resize ->
      if $(window).width() < 1140
        $(".search-tools").css position: "absolute"
      else
        $(".search-tools").css position: "fixed"

  Template.results.created = ->
    # infinite scrolling
    $(window).on 'scroll', ->
      if $(window).scrollTop() >= $(document).height() - $(window).height() - 1140
        subscribeToNext(25)

  subscribeToNext = (numResults) ->
    next = Session.get('lastResultSubscribed') + numResults
    Session.set 'lastResultSubscribed', next
    Meteor.subscribe 'publications-by-ids', Session.get('resultIds').slice 0, next

  Template.results.publications = ->
    Publications.find
      _id:
        $in: Session.get 'resultIds'
    ,
      limit: Session.get 'lastResultSubscribed'
