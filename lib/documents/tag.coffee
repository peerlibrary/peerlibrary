class @Tag extends Document
  # created: timestamp when tag was created
  # name:
  #   en: name of the tag in English (ISO 639-1)
  # slug:
  #   en: slug of the tag in English (ISO 639-1)

  @Meta
    name: 'Tag'
    fields: =>
      # TODO: Define generator function for slugs
      slug: @GeneratedField 'self', ['name']

