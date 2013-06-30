Deps.autorun ->
  if not Session.equals 'currentSearchLimit', 0
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
      subscribeToNext 25

subscribeToNext = (numResults) ->
  Session.set 'currentSearchLimit', Session.get('currentSearchLimit') + numResults

Template.results.publications = ->
  if not Session.get 'currentSearchQuery' or not Session.get 'currentSearchLimit'
    return

  Publications.find
    'searchResult.query': Session.get 'currentSearchQuery'
  ,
    sort:
      'searchResult.order': 1
    limit: Session.get 'currentSearchLimit'
