class @Annotation extends AccessDocument
  # access: 0 (private, ACCESS.PRIVATE), 1 (public, ACCESS.PUBLIC)
  # readPersons: if private access, list of persons who have read permissions
  # readGroups: if private access, list of groups who have read permissions
  # createdAt: timestamp when document was created
  # updatedAt: timestamp of this version
  # author:
  #   _id: person id
  #   slug
  #   givenName
  #   familyName
  #   gravatarHash
  #   user
  #     username
  # body: in HTML
  # publication:
  #   _id: publication's id
  # references: made in the body of annotation or comments
  #   highlights: list of
  #     _id
  #   annotations: list of
  #     _id
  #   publications: list of
  #     _id
  #     slug
  #     title
  #   persons: list of
  #     _id
  #     slug
  #     givenName
  #     familyName
  #     gravatarHash
  #     user
  #       username
  #   tags: list of
  #     _id
  #     name: ISO 639-1 dictionary
  #     slug: ISO 639-1 dictionary
  # tags: list of
  #   tag:
  #     _id
  #     name: ISO 639-1 dictionary
  #     slug: ISO 639-1 dictionary
  # referencingAnnotations: list of (reverse field from Annotation.references.annotations)
  #   _id: annotation id
  # license: license information, if known
  # local (client only): is this annotation just a temporary annotation on the client side
  # editing (client only): is this annotation being edited

  @Meta
    name: 'Annotation'
    fields: =>
      author: @ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username']
      publication: @ReferenceField Publication, [], true, 'annotations'
      references:
        highlights: [@ReferenceField Highlight, [], true, 'referencingAnnotations']
        annotations: [@ReferenceField 'self', [], true, 'referencingAnnotations']
        publications: [@ReferenceField Publication, ['slug', 'title'], true, 'referencingAnnotations']
        persons: [@ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username'], true, 'referencingAnnotations']
        # TODO: Are we sure that we want a reverse field for tags? This could become a huge list for popular tags.
        tags: [@ReferenceField Tag, ['name', 'slug'], true, 'referencingAnnotations']
      tags: [
        tag: @ReferenceField Tag, ['name', 'slug']
      ]
