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
  'mousedown': (event, template) ->
    # Save mouse position so we can later detect selection actions in click handler
    template.data._previousMousePosition =
      pageX: event.pageX
      pageY: event.pageY

  'click': (event, template) ->
    # Don't redirect if user interacted with one of the actionable controls on the item
    return if $(event.target).closest('.actionable').length > 0

    # Don't redirect if this might have been a selection
    event.previousMousePosition = template.data._previousMousePosition
    return if event.previousMousePosition and (Math.abs(event.previousMousePosition.pageX - event.pageX) > 1 or Math.abs(event.previousMousePosition.pageY - event.pageY) > 1)

    # Redirect user to the highlight
    Meteor.Router.toNew Meteor.Router.highlightIdPath template.data._id
