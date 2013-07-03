Deps.autorun ->
  Session.set 'currentSearchQueryCountPublications', 0
  Session.set 'currentSearchQueryCountPeople', 0
  if not Session.equals('currentSearchLimit', 0) and Session.get('currentSearchQuery')
    Meteor.subscribe 'search-results', Session.get('currentSearchQuery'), Session.get('currentSearchLimit')

Template.results.rendered = ->
  $('.chzn').chosen()

  $('.scrubber').iscrubber()

  'click .preview-link': ->
    $('.abstract').css display: 'block'

  $('#score-range').slider
    range: true
    min: 0
    max: 100
    values: [0, 100]
    step: 10
    slide: (event, ui) ->
      $('#score').val(ui.values[ 0 ] + ' - ' + ui.values[ 1 ])

  $('#score').val($('#score-range').slider('values', 0) +
    ' - ' + $('#score-range').slider('values', 1))

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
  # Infinite scrolling
  $(window).on 'scroll', ->
    if $(window).scrollTop() >= $(document).height() - $(window).height() - 1140
      subscribeToNext 10

subscribeToNext = (numResults) ->
  Session.set 'currentSearchLimit', Session.get('currentSearchLimit') + numResults

Template.results.publications = ->
  if Session.equals('currentSearchLimit', 0) or not Session.get('currentSearchQuery')
    return

  searchResult = SearchResults.findOne
    query: Session.get 'currentSearchQuery'

  if not searchResult
    return

  Session.set 'currentSearchQueryCountPublications', searchResult.countPublications
  Session.set 'currentSearchQueryCountPeople', searchResult.countPeople

  Publications.find
    'searchResult.id': searchResult._id
  ,
    sort:
      'searchResult.order': 1
    limit: Session.get 'currentSearchLimit'

Template.resultsCount.publications = ->
  Session.get 'currentSearchQueryCountPublications'

Template.resultsCount.people = ->
  Session.get 'currentSearchQueryCountPeople'
