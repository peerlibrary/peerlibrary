catalogSettings =
  subscription: 'highlights'
  documentClass: Highlight
  variables:
    active: 'highlightsActive'
    ready: 'currentHighlightsReady'
    loading: 'currentHighlightsLoading'
    count: 'currentHighlightsCount'
    filter: 'currentHighlightsFilter'
    limit: 'currentHighlightsLimit'
    limitIncreasing: 'currentHighlightsLimitIncreasing'
    sort: 'currentHighlightsSort'
  signedInNoDocumentsMessage: "Create the first by highlighting text in one of the publications."
  signedOutNoDocumentsMessage: "Sign in and create the first."

Catalog.create catalogSettings

Template.highlights.catalogSettings = ->
  catalogSettings

Template.highlightCatalogItem.events =
  'mousedown': (e, template) ->
    # Save mouse position so we can later detect selection actions in click handler
    template.data._previousMousePosition =
      pageX: e.pageX
      pageY: e.pageY

  'click': (e, template) ->
    # Don't redirect if user interacted with one of the actionable controls on the item
    return if $(e.target).closest('.actionable').length > 0

    # Don't redirect if this might have been a selection
    e.previousMousePosition = template.data._previousMousePosition
    return if e.previousMousePosition and (Math.abs(e.previousMousePosition.pageX - e.pageX) > 1 or Math.abs(e.previousMousePosition.pageY - e.pageY) > 1)

    # Redirect user to the highlight
    Meteor.Router.toNew Meteor.Router.highlightIdPath template.data._id
