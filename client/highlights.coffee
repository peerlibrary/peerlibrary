Template.highlights.helpers
  catalogSettings: ->
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

EnableCatalogItemLink Template.highlightCatalogItem
