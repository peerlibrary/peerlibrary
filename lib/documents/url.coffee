class @Url extends BaseDocument
  # createdAt: timestamp when document was created
  # updatedAt: timestamp of this version
  # url: URL where document is pointing at
  # referencingAnnotations: list of (reverse field from Annotation.references.urls)
  #   _id: annotation id

  @Meta
    name: 'Url'
    triggers: =>
      updatedAt: UpdatedAtTrigger ['url']
