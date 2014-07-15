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
