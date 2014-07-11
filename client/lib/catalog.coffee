# The ammount by which we increate the limit of returned results
LIMIT_INCREASE_STEP = 10

Template.catalogFilter.documentsName = ->
  @documentClass.verboseNamePlural()

Template.catalogSort.field = ->
  index = Session.get @variables.sort
  @documentClass.PUBLISH_CATALOG_SORT[index].name

Template.catalogSort.events
  'click .dropdown-trigger': (e, template) ->
    # Make sure only the trigger toggles the dropdown
    return if $(e.target).closest('.dropdown-anchor').length

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
  'click button': (e, template) ->
    Session.set @_parent.variables.sort, @_index
    $(template.firstNode).closest('.dropdown-anchor').hide()

    return # Make sure CoffeeScript does not return anything

Template.catalogFilter.events
  'keyup .filter input': (e, template) ->
    filter = $(template.findAll '.filter input').val()
    Session.set template.data.variables.filter, filter

    return # Make sure CoffeeScript does not return anything

# Helper that enables a list of documents with infinite scrolling and filtering
class @Catalog
  @catalogActiveVariables = []

  @create: (subscription, documentClass, templates, variables) ->
    limitIncreasing = false

    @catalogActiveVariables.push variables.active

    Deps.autorun ->
      # Every time filter or sort is changed, we reset counts
      # (We don't want to reset counts on currentLimit change)
      Session.get variables.filter
      Session.get variables.sort
      Session.set variables.count, 0
      Session.set variables.limit, INITIAL_CATALOG_LIMIT
      limitIncreasing = false

    Deps.autorun ->
      Session.set variables.ready, false
      if Session.get(variables.active) and Session.get(variables.limit)
        Session.set variables.loading, true
        Meteor.subscribe subscription, Session.get(variables.limit), Session.get(variables.filter), Session.get(variables.sort),
          onReady: ->
            Session.set variables.ready, true
            Session.set variables.loading, false
          onError: ->
            # TODO: Should we display some error?
            Session.set variables.loading, false
      else
        Session.set variables.loading, false

    assert not templates.main.created
    templates.main.created = ->
      $(window).on 'scroll.directory', ->
        if $(document).height() - $(window).scrollTop() <= 2 * $(window).height()
          increaseLimit LIMIT_INCREASE_STEP

        return # Make sure CoffeeScript does not return anything

    assert not templates.main.rendered
    templates.main.rendered = ->
      if Session.get variables.ready
        limitIncreasing = false
        # Trigger scrolling to automatically start loading more results until whole screen is filled
        $(window).trigger('scroll')

    assert not templates.main.destroyed
    templates.main.destroyed = ->
      $(window).off '.directory'

    templates.main.documents = ->
      return unless Session.get(variables.limit)

      searchResult = SearchResult.documents.findOne
        name: subscription
        query: [Session.get(variables.filter), Session.get(variables.sort)]

      return unless searchResult

      Session.set variables.count, searchResult["count#{documentClass.name}s"]

      documentClass.documents.find
        'searchResult._id': searchResult._id
      ,
        sort: [
          ['searchResult.order', 'asc']
        ]
        limit: Session.get variables.limit

    templates.count?.documentsCount = ->
      Session.get variables.count

    templates.empty.noDocuments = ->
      Session.get(variables.ready) and not Session.get(variables.count)

    templates.empty.documentsFilter = ->
      Session.get(variables.filter)

    templates.loading.documentsLoading = ->
      Session.get(variables.loading)

    templates.loading.moreDocuments = ->
      Session.get(variables.ready) and Session.get(variables.limit) < Session.get(variables.count)

    templates.loading.events
      'click .load-more': (e, template) ->
        e.preventDefault()
        limitIncreasing = false # We want to force loading more in every case
        increaseLimit LIMIT_INCREASE_STEP

        return # Make sure CoffeeScript does not return anything

    increaseLimit = (pageSize) ->
      if limitIncreasing
        return
      if Session.get(variables.limit) < Session.get(variables.count)
        limitIncreasing = true
        Session.set variables.limit, (Session.get(variables.limit) or 0) + pageSize
