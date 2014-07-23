Catalog.create 'highlights', Highlight,
  main: Template.highlights
  count: Template.highlightsCount
  loading: Template.highlightsLoading
,
  active: 'highlightsActive'
  ready: 'currentHighlightsReady'
  loading: 'currentHighlightsLoading'
  count: 'currentHighlightsCount'
  filter: 'currentHighlightsFilter'
  limit: 'currentHighlightsLimit'
  sort: 'currentHighlightsSort'

Template.highlights.catalogSettings = ->
  documentClass: Highlight
  variables:
    filter: 'currentHighlightsFilter'
    sort: 'currentHighlightsSort'

Template.highlightCatalogItem.events =
  'mousedown': (e, template) ->
    # Save mouse position so we can later detect selection actions in click handler
    template.data._previousMousePosition =
      pageX: e.pageX
      pageY: e.pageY

  'click': (e, template) ->
    # Don't redirect if user interacted with one of the actionable controls on the item
    return if $(e.target).closest('.actionable').length > 0

    e.previousMousePosition = template.data._previousMousePosition
    template.data._previousMousePosition = null

    # Don't redirect if this might have been a selection
    return if e.previousMousePosition and (Math.abs(e.previousMousePosition.pageX - e.pageX) > 1 or Math.abs(e.previousMousePosition.pageY - e.pageY) > 1)

    # Redirect user to the highlight
    Meteor.Router.toNew Meteor.Router.highlightIdPath template.data._id
