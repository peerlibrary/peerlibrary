class @Tag extends Document
  # created: timestamp when tag was created
  # name:
  #   en: name of the tag in English (ISO 639-1)
  # slug:
  #   en: slug of the tag in English (ISO 639-1)
  # referencingAnnotations: list of (reverse field from Annotation.references.tags)
  #   _id: annotation id

  @Meta
    name: 'Tag'
    fields: =>
      # TODO: Define generator function for slugs
      slug: @GeneratedField 'self', ['name']
