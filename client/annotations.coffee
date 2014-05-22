Catalog.create 'annotations', Annotation,
  main: Template.annotations
  empty: Template.noAnnotations
  loading: Template.annotationsLoading
,
  active: 'annotationsActive'
  ready: 'currentAnnotationsReady'
  loading: 'currentAnnotationsLoading'
  count: 'currentAnnotationsCount'
  filter: 'currentAnnotationsFilter'
  limit: 'currentAnnotationsLimit'
  sort: 'currentAnnotationsSort'

Template.annotations.catalogSettings = ->
  documentClass: Annotation
  variables:
    filter: 'currentAnnotationsFilter'
    sort: 'currentAnnotationsSort'
