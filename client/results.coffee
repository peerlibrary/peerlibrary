searchLimitIncreasing = false

currentSearchQueryCount = ->
  (Session.get('currentSearchQueryCountPublications') or 0) + (Session.get('currentSearchQueryCountPersons') or 0)

Deps.autorun ->
  # Every time search query is changed, we reset counts
  # (We don't want to reset counts on currentSearchLimit change)
  Session.get 'currentSearchQuery'
  Session.set 'currentSearchQueryCountPublications', 0
  Session.set 'currentSearchQueryCountPersons', 0

  searchLimitIncreasing = false

Deps.autorun ->
  Session.set 'currentSearchQueryReady', false
  if Session.get('currentSearchLimit') and Session.get('currentSearchQuery')
    Session.set 'currentSearchQueryLoading', true
    Meteor.subscribe 'search-results', Session.get('currentSearchQuery'), Session.get('currentSearchLimit'),
      onReady: ->
        Session.set 'currentSearchQueryReady', true
        Session.set 'currentSearchQueryLoading', false
      onError: ->
        # TODO: Should we display some error?
        Session.set 'currentSearchQueryLoading', false
  else
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
  if searchLimitIncreasing
    return
  if Session.get('currentSearchLimit') < currentSearchQueryCount()
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
  Session.set 'currentSearchQueryCountPersons', searchResult.countPersons

  Publications.find
    'searchResult._id': searchResult._id
  ,
    sort: [
      ['searchResult.order', 'asc']
    ]
    limit: Session.get 'currentSearchLimit'

Template.resultsCount.publications = ->
  Session.get 'currentSearchQueryCountPublications'

Template.resultsCount.persons = ->
  Session.get 'currentSearchQueryCountPersons'

Template.noResults.noResults = ->
  Session.get('currentSearchQueryReady') and not currentSearchQueryCount()

Template.resultsLoad.loading = ->
  Session.get('currentSearchQueryLoading')

Template.resultsLoad.more = ->
  Session.get('currentSearchQueryReady') and Session.get('currentSearchLimit') < currentSearchQueryCount()

Template.resultsLoad.events =
  'click .load-more': (e, template) ->
    e.preventDefault()
    searchLimitIncreasing = false # We want to force loading more in every case
    increaseSearchLimit 10

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

sidebarIntoQuery = (template) ->
  # TODO: Add other fields as well
  title: $(template.findAll '#title').val()

Template.sidebarSearch.events =
  'blur #title': (e, template) ->
    structuredQueryChange(sidebarIntoQuery template)

  'change #title': (e, template) ->
    structuredQueryChange(sidebarIntoQuery template)

  'keyup #title': (e, template) ->
    structuredQueryChange(sidebarIntoQuery template)

  'paste #title': (e, template) ->
    structuredQueryChange(sidebarIntoQuery template)

  'cut #title': (e, template) ->
    structuredQueryChange(sidebarIntoQuery template)

  'submit #sidebar-search': (e, template) ->
    e.preventDefault()
    structuredQueryChange(sidebarIntoQuery template)

Template.sidebarSearch.minPublicationDate = ->
  searchResult = SearchResults.findOne
    query: null

  moment.utc(searchResult.minPublicationDate).year() if searchResult?.minPublicationDate

Template.sidebarSearch.maxPublicationDate = ->
  searchResult = SearchResults.findOne
    query: null

  moment.utc(searchResult.maxPublicationDate).year() if searchResult?.maxPublicationDate

Deps.autorun ->
  # TODO: Set from structured query
  $('#title').val(Session.get 'currentSearchQuery')
