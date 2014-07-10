class @Tag extends Document
  # createdAt: timestamp when document was created
  # updatedAt: timestamp of this version
  # lastActivity: time of the last tag activity (something tagged, etc.)
  # name:
  #   en: name of the tag in English (ISO 639-1)
  # slug:
  #   en: slug of the tag in English (ISO 639-1)
  # referencingAnnotations: list of (reverse field from Annotation.references.tags)
  #   _id: annotation id

  @Meta
    name: 'Tag'
    fields: =>
      slug: @GeneratedField 'self', ['name']
    triggers: =>
      updatedAt: UpdatedAtTrigger ['name']
