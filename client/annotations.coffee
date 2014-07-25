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

Template.annotationCatalogItem.events =
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

    # Redirect user to the annotation
    Meteor.Router.toNew Meteor.Router.annotationIdPath template.data._id

Template.annotationCatalogItem.commentsCountDescription = ->
  Comment.verboseNameWithCount @commentsCount
