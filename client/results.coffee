searchLimitIncreasing = false

currentSearchQueryCount = ->
  (Session.get('currentSearchQueryCountPublications') or 0) + (Session.get('currentSearchQueryCountPersons') or 0)

Tracker.autorun ->
  # Every time search query is changed, we reset counts
  # (We don't want to reset counts on currentSearchLimit change)
  Session.get 'currentSearchQuery'
  Session.set 'currentSearchQueryCountPublications', 0
  Session.set 'currentSearchQueryCountPersons', 0

  searchLimitIncreasing = false

Tracker.autorun ->
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

Tracker.autorun ->
  if Session.get 'searchActive'
    Meteor.subscribe 'statistics'

Template.results.created = ->
  $(window).on 'scroll.results', ->
    if $(document).height() - $(window).scrollTop() <= 2 * $(window).height()
      increaseSearchLimit 10

    return # Make sure CoffeeScript does not return anything

Template.results.rendered = ->
  if Session.get 'currentSearchQueryReady'
    searchLimitIncreasing = false
    # Trigger scrolling to automatically start loading more results until whole screen is filled
    $(window).trigger('scroll')

Template.results.destroyed = ->
  $(window).off '.results'

increaseSearchLimit = (pageSize) ->
  if searchLimitIncreasing
    return
  if Session.get('currentSearchLimit') < currentSearchQueryCount()
    searchLimitIncreasing = true
    Session.set 'currentSearchLimit', (Session.get('currentSearchLimit') or 0) + pageSize

Template.results.helpers
  publications: ->
    if not Session.get('currentSearchLimit') or not Session.get('currentSearchQuery')
      return

    searchResult = SearchResult.documents.findOne
      name: 'search-results'
      query: Session.get 'currentSearchQuery'

    return if not searchResult

    Session.set 'currentSearchQueryCountPublications', searchResult.countPublications
    Session.set 'currentSearchQueryCountPersons', searchResult.countPersons

    Publication.documents.find
      'searchResult._id': searchResult._id
    ,
      sort: [
        ['searchResult.order', 'asc']
      ]
      limit: Session.get 'currentSearchLimit'
      fields:
        searchResult: 0

Template.resultsCount.helpers
  publications: ->
    Session.get 'currentSearchQueryCountPublications'

  persons: ->
    Session.get 'currentSearchQueryCountPersons'

  noResults: ->
    Session.get('currentSearchQueryReady') and not currentSearchQueryCount()

  publicationsCountDescription: ->
    Publication.verboseNameWithCount Session.get('currentSearchQueryCountPublications')

  personsCountDescription: ->
    Person.verboseNameWithCount Session.get('currentSearchQueryCountPublications')

Template.resultsLoad.helpers
  loading: ->
    Session.get('currentSearchQueryLoading')

  more: ->
    Session.get('currentSearchQueryReady') and Session.get('currentSearchLimit') < currentSearchQueryCount()

  publications: ->
    Session.get 'currentSearchQueryCountPublications'

Template.resultsLoad.events
  'click .load-more': (event, template) ->
    event.preventDefault()
    searchLimitIncreasing = false # We want to force loading more in every case
    increaseSearchLimit 10

    return # Make sure CoffeeScript does not return anything

Template.resultsSearchInvitation.helpers
  searchInvitation: ->
    not Session.get('currentSearchQuery')

Template.sidebarSearch.created = ->
  @_searchQueryHandle = null
  @_dateRangeHandle = null

Template.sidebarSearch.rendered = ->
  @_searchQueryHandle?.stop()
  @_searchQueryHandle = Tracker.autorun =>
    # Sync input field unless change happened because of this input field itself
    @$('#general').val(Session.get 'currentSearchQuery') unless structuredQueryChangeLock > 0

  @_dateRangeHandle?.stop()
  @_dateRangeHandle = Tracker.autorun =>
    statistics = Statistics.documents.findOne {},
      fields:
        minPublicationDate: 1
        maxPublicationDate: 1

    $publicationDate = @$('#publication-date')
    $slider = @$('#date-range')

    unless statistics?.minPublicationDate and statistics?.maxPublicationDate
      $publicationDate.val('')
      $slider.slider('destroy') if $slider.data('ui-slider')
      return

    min = moment.utc(statistics.minPublicationDate).year()
    max = moment.utc(statistics.maxPublicationDate).year()

    [start, end] = $publicationDate.val().split(' - ') if $publicationDate.val()
    start = parseInt(start) or min
    end = parseInt(end) or max

    start = min if start < min
    end = max if end > max

    $slider.slider
      disabled: true # TODO: For now disabled
      range: true
      min: min
      max: max
      values: [start, end]
      step: 1
      slide: (event, ui) ->
        $publicationDate.val(ui.values[0] + ' - ' + ui.values[1])

    $publicationDate.val($slider.slider('values', 0) + ' - ' + $slider.slider('values', 1))

  @$('.chzn').chosen
    no_results_text: "No tag match"

Template.sidebarSearch.destroyed = ->
  @_searchQueryHandle?.stop()
  @_searchQueryHandle = null
  @_dateRangeHandle?.stop()
  @_dateRangeHandle = null

sidebarIntoQuery = (template) ->
  # TODO: Add other fields as well
  general: $(template.findAll '#general').val()

Template.sidebarSearch.events
  'blur #general': (event, template) ->
    structuredQueryChange(sidebarIntoQuery template)
    return # Make sure CoffeeScript does not return anything

  'change #general': (event, template) ->
    structuredQueryChange(sidebarIntoQuery template)
    return # Make sure CoffeeScript does not return anything

  'keyup #general': (event, template) ->
    structuredQueryChange(sidebarIntoQuery template)
    return # Make sure CoffeeScript does not return anything

  'paste #general': (event, template) ->
    structuredQueryChange(sidebarIntoQuery template)
    return # Make sure CoffeeScript does not return anything

  'cut #general': (event, template) ->
    structuredQueryChange(sidebarIntoQuery template)
    return # Make sure CoffeeScript does not return anything

  'submit #sidebar-search': (event, template) ->
    event.preventDefault()
    structuredQueryChange(sidebarIntoQuery template)
    return # Make sure CoffeeScript does not return anything

# We do not want location to be updated for every key press, because this really makes browser history hard to navigate
# TODO: This might make currentSearchQuery be overriden with old value if it happens that exactly after 500 ms user again presses a key, but location is changed to old value which sets currentSearchQuery and thus input field back to old value
updateSearchLoction = _.debounce (query) ->
  Meteor.Router.toNew Meteor.Router.searchPath query
, 500

Tracker.autorun ->
  if Session.get 'searchActive'
    updateSearchLoction Session.get 'currentSearchQuery'
