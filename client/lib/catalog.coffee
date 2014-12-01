# The amount by which we increase the limit of returned results
LIMIT_INCREASE_STEP = 10

# List of all session variables that activate views with catalogs (used to determine infinite scrolling)
globals = @
globals.catalogActiveVariables = []

# Subscribe the client to catalog's documents
Template.catalog.created = ->
  variables = @data.variables

  # Make sure to access the global catalogActiveVariables variable
  globals.catalogActiveVariables = _.union globals.catalogActiveVariables, [variables.active]

  # We need a reset signal that will rerun the search
  # when the ready variable is set to false from the router
  reset = new Variable false
  wasReady = new Variable false

  @_resetSignalHandle?.stop()
  @_resetSignalHandle = Deps.autorun =>
    # Detect when ready is turned to false
    ready = Session.get(variables.ready)
    if wasReady() and not ready
      reset.set true
      wasReady.set false

  @_searchParametersHandle?.stop()
  @_searchParametersHandle = Deps.autorun =>
    # Every time filter or sort is changed, we reset counts
    # (We don't want to reset counts on currentLimit change)
    Session.get variables.filter
    Session.get variables.sort
    Session.set variables.ready, false
    Session.set variables.limit, INITIAL_CATALOG_LIMIT
    Session.set variables.limitIncreasing, false

  subscriptionHandle = null

  @_subscriptionAutorunHandle?.stop()
  @_subscriptionAutorunHandle = Deps.autorun =>
    # Listen for the reset signal, so the search is
    # rerun when ready is set to false from the outside
    reset()
    reset.set false
    if Session.get(variables.active) and Session.get(variables.limit)
      Session.set variables.loading, true
      # Make sure there is only one subscription being executed at once
      subscriptionHandle.stop() if subscriptionHandle
      subscriptionHandle = Meteor.subscribe @data.subscription, Session.get(variables.limit), Session.get(variables.filter), Session.get(variables.sort),
        onReady: =>
          Session.set variables.ready, true
          wasReady.set true

          Session.set variables.loading, false
        onError: ->
          # TODO: Should we display some error?
          Session.set variables.loading, false
    else
      Session.set variables.loading, false

  @_searchResultHandle?.stop()
  @_searchResultHandle = Deps.autorun =>
    fields = {}
    fields["count#{ @data.documentClass.Meta.collection._name }"] = 1

    searchResultCursor = SearchResult.documents.find
      name: @data.subscription
      query: [Session.get(variables.filter), Session.get(variables.sort)]
    ,
      fields: fields

    # Store how many results there are
    searchResultCursor.observe
      added: (document) =>
        Session.set variables.count, document["count#{ @data.documentClass.Meta.collection._name }"]
      changed: (newDocument, oldDocument) =>
        Session.set variables.count, newDocument["count#{ @data.documentClass.Meta.collection._name }"]

Template.catalog.destroyed = ->
  @_resetSignalHandle?.stop()
  @_resetSignalHandle = null
  @_searchParametersHandle?.stop()
  @_searchParametersHandle = null
  @_subscriptionAutorunHandle?.stop()
  @_subscriptionAutorunHandle = null
  @_searchResultHandle?.stop()
  @_searchResultHandle = null

Template.catalogFilter.documentsName = ->
  @documentClass.verboseNamePlural()

Template.catalogFilter.filter = ->
  Session.get(@variables.filter) or ''

Template.catalogSort.field = ->
  index = Session.get @variables.sort
  @documentClass.PUBLISH_CATALOG_SORT[index].name

Template.catalogSort.events
  'click .dropdown-trigger': (event, template) ->
    # Make sure only the trigger toggles the dropdown, by
    # excluding clicks inside the content of this dropdown
    return if $.contains template.find('.dropdown-anchor'), event.target

    $(template.findAll '.dropdown-anchor').toggle()

    return # Make sure CoffeeScript does not return anything

Template.catalogSortSelection.options = ->
  # Modify the data with parent variables
  # TODO: Change when meteor allows to access parent context
  index = 0
  _.map @documentClass.PUBLISH_CATALOG_SORT, (sorting) =>
    sorting._parent = @
    sorting._index = index++
    sorting

Template.catalogSortOption.events
  'click button': (event, template) ->
    Session.set @_parent.variables.sort, @_index
    $(template.firstNode).closest('.dropdown-anchor').hide()

    return # Make sure CoffeeScript does not return anything

Template.catalogFilter.events
  'keyup .filter input': (event, template) ->
    filter = $(template.findAll '.filter input').val()
    Session.set @variables.filter, filter

    return # Make sure CoffeeScript does not return anything

Template.catalogCount.ready = ->
  Session.get @variables.ready

Template.catalogCount.count = ->
  Session.get @variables.count

Template.catalogCount.countDescription = ->
  @documentClass.verboseNameWithCount Session.get(@variables.count)

Template.catalogCount.filter = ->
  Session.get @variables.filter

Template.catalogCount.documentsName = ->
  @documentClass.verboseNamePlural()

Template.catalogList.created = ->
  $(window).on 'scroll.catalog', =>
    if $(document).height() - $(window).scrollTop() <= 2 * $(window).height()
      increaseLimit LIMIT_INCREASE_STEP, @data.variables

    return # Make sure CoffeeScript does not return anything

onCatalogRendered = (template, variables) ->
  renderedChildren = $(template.find '.item-list').children().length
  expectedChildren = Math.min(Session.get(variables.count), Session.get(variables.limit))

  # Not all elements are yet in the DOM. Let's return here.
  # There will be another rendered call when they are added.
  return if renderedChildren isnt expectedChildren

  Session.set variables.limitIncreasing, false
  # Trigger scrolling to automatically start loading more results until whole screen is filled
  $(window).trigger('scroll')

Template.catalogList.rendered = ->
  Deps.afterFlush =>
    # Make sure onCatalogRendered gets executed after rendered is done and new elements are in the DOM.
    # Otherwise we might increase limit multiple times in a row, before the DOM updates.
    onCatalogRendered @, @data.variables

  # Focus on the filter
  $(@find '.filter input').focus()

Template.catalogList.destroyed = ->
  $(window).off '.catalog'

Template.catalogList.documents = ->
  # Make sure we don't show documents if ready gets set to false
  return unless Session.get @variables.ready

  searchResult = SearchResult.documents.findOne
    name: @subscription
    query: [Session.get(@variables.filter), Session.get(@variables.sort)]

  return unless searchResult

  @documentClass.documents.find
    'searchResult._id': searchResult._id
  ,
    sort: [
      ['searchResult.order', 'asc']
    ]
    limit: Session.get @variables.limit
    fields:
      searchResult: 0

Template.catalogItem.documentIsPublication = ->
  @ instanceof Publication

Template.catalogItem.documentIsPerson = ->
  @ instanceof Person

Template.catalogItem.documentIsHighlight = ->
  @ instanceof Highlight

Template.catalogItem.documentIsAnnotation = ->
  @ instanceof Annotation

Template.catalogItem.documentIsGroup = ->
  @ instanceof Group

Template.catalogItem.documentIsCollection = ->
  @ instanceof Collection

Template.catalogItem.documentIsLoggedError = ->
  @ instanceof LoggedError

Template.catalogLoading.loading = ->
  Session.get @variables.loading

Template.catalogLoading.more = ->
  Session.get(@variables.ready) and Session.get(@variables.limit) < Session.get(@variables.count)

Template.catalogLoading.count = ->
  Session.get @variables.count

Template.catalogLoading.documentsName = ->
  @documentClass.verboseNamePlural()

Template.catalogLoading.events
  'click .load-more': (event, template) ->
    event.preventDefault()
    Session.set @variables.limitIncreasing, false # We want to force loading more in every case
    increaseLimit LIMIT_INCREASE_STEP, @variables

    return # Make sure CoffeeScript does not return anything

increaseLimit = (pageSize, variables) ->
  return if Session.get(variables.limitIncreasing)

  if Session.get(variables.limit) < Session.get(variables.count)
    Session.set variables.limitIncreasing, true
    Session.set variables.limit, (Session.get(variables.limit) or 0) + pageSize
