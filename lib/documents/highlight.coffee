class @Highlight extends Document
  # created: timestamp when document was created
  # updated: timestamp of this version
  # author:
  #   _id: author's person id
  #   slug: author's person id
  #   givenName
  #   familyName
  #   gravatarHash
  #   user
  #     username
  # publication:
  #   _id: publication's id
  # quote: quote made by this highlight
  # target: open annotation standard compatible target information
  # annotations: list of (reverse field from Annotation.highlights)
  #   _id: annotation id

  @Meta
    name: 'Highlight'
    fields: =>
      author: @ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username']
      publication: @ReferenceField Publication
