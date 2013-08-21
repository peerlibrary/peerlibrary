searchLimitIncreasing = false

Deps.autorun ->
  # Every time search query is changed, we reset counts
  # (We don't want to reset counts on currentSearchLimit change)
  Session.get 'currentSearchQuery'
  Session.set 'currentSearchQueryCountPublications', 0
  Session.set 'currentSearchQueryCountPeople', 0

  searchLimitIncreasing = false

Deps.autorun ->
  Session.set 'currentSearchQueryReady', false
  if Session.get('currentSearchLimit') and Session.get('currentSearchQuery')
    Session.set 'currentSearchQueryLoading', true
    Meteor.subscribe 'search-results', Session.get('currentSearchQuery'), Session.get('currentSearchLimit'), ->
      Session.set 'currentSearchQueryReady', true
      Session.set 'currentSearchQueryLoading', false

Deps.autorun ->
  if Session.get 'indexActive'
    Meteor.subscribe 'search-available'

Template.results.rendered = ->
  $(@findAll '.scrubber').iscrubber()

  if Session.get 'currentSearchQueryReady'
    searchLimitIncreasing = false

Template.results.created = ->
  $(window).on 'scroll.results', ->
    if $(document).height() - $(window).scrollTop() <= 2 * $(window).height()
      increaseSearchLimit 10

Template.results.destroyed = ->
  $(window).off 'scroll.results'

increaseSearchLimit = (pageSize) ->
  if not searchLimitIncreasing
    searchLimitIncreasing = true
    Session.set 'currentSearchLimit', (Session.get('currentSearchLimit') or 0) + pageSize

Template.results.publications = ->
  if not Session.get('currentSearchLimit') or not Session.get('currentSearchQuery')
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
    sort: [
      ['searchResult.order', 'asc']
    ]
    limit: Session.get 'currentSearchLimit'

Template.resultsCount.publications = ->
  Session.get 'currentSearchQueryCountPublications'

Template.resultsCount.people = ->
  Session.get 'currentSearchQueryCountPeople'

Template.noResults.noResults = ->
  Session.get('currentSearchQueryReady') and not Session.get('currentSearchQueryCountPublications') and not Session.get('currentSearchQueryCountPeople')

Template.resultsLoading.resultsLoading = ->
  Session.get('currentSearchQueryLoading')

Template.resultsSearchInvitation.searchInvitation = ->
  not Session.get('currentSearchQuery')

Template.publicationSearchResult.displayDay = (time) ->
  moment(time).format 'MMMM Do YYYY'

Template.publicationSearchResult.events =
  'click .preview-link': (e, template) ->
    e.preventDefault()
    Meteor.subscribe 'publications-by-id', @_id, ->
      Deps.afterFlush ->
        $(template.findAll '.abstract').slideToggle(200)

Template.sidebarSearch.rendered = ->
  $(@findAll '.chzn').chosen
    no_results_text: "No tag match"

  publicationDate = $(@findAll '#publication-date')
  [start, end] = publicationDate.val().split(' - ') if publicationDate.val()
  start = publicationDate.data('min') unless start
  end = publicationDate.data('max') unless end

  slider = $(@findAll '#date-range').slider
    range: true
    min: publicationDate.data('min')
    max: publicationDate.data('max')
    values: [start, end]
    step: 1
    slide: (event, ui) ->
      publicationDate.val(ui.values[0] + ' - ' + ui.values[1])

  publicationDate.val(slider.slider('values', 0) + ' - ' + slider.slider('values', 1))

Template.sidebarSearch.events =
  # TODO: Parse search input and map to #title and others

  'blur #title': (e, template) ->
    Session.set 'currentSearchQuery', $(template.findAll '#title').val()

  'change #title': (e, template) ->
    Session.set 'currentSearchQuery', $(template.findAll '#title').val()

  'keyup #title': (e, template) ->
    Session.set 'currentSearchQuery', $(template.findAll '#title').val()

  'paste #title': (e, template) ->
    Session.set 'currentSearchQuery', $(template.findAll '#title').val()

  'cut #title': (e, template) ->
    Session.set 'currentSearchQuery', $(template.findAll '#title').val()

  'submit #sidebar-search': (e, template) ->
    e.preventDefault()
    Session.set 'currentSearchQuery', $(template.findAll '#title').val()

Template.sidebarSearch.minPublicationDate = ->
  searchResult = SearchResults.findOne
    query: null

  moment.utc(searchResult.minPublicationDate).year() if searchResult?.minPublicationDate

Template.sidebarSearch.maxPublicationDate = ->
  searchResult = SearchResults.findOne
    query: null

  moment.utc(searchResult.maxPublicationDate).year() if searchResult?.maxPublicationDate
