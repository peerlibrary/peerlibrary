Template.annotations.helpers
  catalogSettings: ->
    subscription: 'annotations'
    documentClass: Annotation
    variables:
      active: 'annotationsActive'
      ready: 'currentAnnotationsReady'
      loading: 'currentAnnotationsLoading'
      count: 'currentAnnotationsCount'
      filter: 'currentAnnotationsFilter'
      limit: 'currentAnnotationsLimit'
      limitIncreasing: 'currentAnnotationsLimitIncreasing'
      sort: 'currentAnnotationsSort'
    signedInNoDocumentsMessage: "Create the first by annotating one of the publications."
    signedOutNoDocumentsMessage: "Sign in and create the first."

EnableCatalogItemLink Template.annotationCatalogItem

Template.annotationCatalogItem.helpers
  commentsCountDescription: ->
    return unless @_id
    Comment.verboseNameWithCount @commentsCount
