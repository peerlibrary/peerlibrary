Template.catalogFilter.collection = ->
  @collection

Template.catalogSort.field = ->
  Session.set @variables.sortName, @sorting[0].name
  Session.set @variables.sort, @sorting[0].sort
  @sorting[0].name

Template.catalogFilter.events
  'keyup .filter input': (e, template) ->
    filter = $(template.findAll '.filter input').val()
    Session.set template.data.variables.filter, filter

    return # Make sure CoffeeScript does not return anything

LIMIT_INCREASE_STEP = 10

# Helper that enables a list of entities with infinite scrolling and filtering
class @Catalog
  @create: (subscription, entityClass, templates, variables) ->
    limitIncreasing = false

    Deps.autorun ->
      # Every time filter is changed, we reset counts
      # (We don't want to reset counts on currentLimit change)
      Session.get variables.filter
      #Session.set variables.count, 0
      Session.set variables.limit, INITIAL_CATALOG_LIMIT
      limitIncreasing = false

    Deps.autorun ->
      Session.set variables.ready, false
      if  Session.get(variables.active) and Session.get(variables.limit)
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

    templates.main.entities = ->
      return if not Session.get(variables.limit)

      searchResult = SearchResult.documents.findOne
        name: subscription
        query: Session.get variables.filter

      return if not searchResult

      Session.set variables.count, searchResult["count#{entityClass.name}s"]

      entityClass.documents.find
        'searchResult._id': searchResult._id
      ,
        sort: [
          ['searchResult.order', 'asc']
        ]
        limit: Session.get variables.limit

    templates.count.entitiesCount = ->
      Session.get variables.count

    templates.empty.noEntities = ->
      Session.get(variables.ready) and not Session.get(variables.count)

    templates.empty.entitiesFilter = ->
      Session.get(variables.filter)

    templates.loading.entitiesLoading = ->
      Session.get(variables.loading)

    templates.loading.moreEntities = ->
      Session.get(variables.ready) and Session.get(variables.limit) < Session.get(variables.count)

    templates.loading.events =
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
