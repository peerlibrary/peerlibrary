do -> # To not pollute the namespace
  Deps.autorun ->
    console.log Session.get 'currentSearchQuery'
    Meteor.subscribe 'publications-by', 'carl-sagan'

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
      $('.search-tools').css
        'position':'absolute'
    else
      $('.search-tools').css
        'position':'fixed'

  Template.results.publications = ->
    Publications.find Session.get 'currentSearchQuery'
