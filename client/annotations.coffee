Catalog.create 'annotations', Annotation,
  main: Template.annotations
  count: Template.annotationsCount
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

Template.annotationCatalogItem.commentsCountDescription = ->
  Comment.verboseNameWithCount @commentsCount
