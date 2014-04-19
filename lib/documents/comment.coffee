class @Comment extends Document
  # createdAt: timestamp when document was created
  # updatedAt: timestamp of this version
  # author:
  #   _id: author's person id
  #   slug: author's person id
  #   givenName
  #   familyName
  #   gravatarHash
  #   user
  #     username
  # annotation
  #   _id
  # publication
  #   _id
  # body: in HTML (inline, no block elements)
  # license: license information, if known

  @Meta
    name: 'Comment'
    fields: =>
      author: @ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username']
      annotation: @ReferenceField Annotation
      publication: @ReferenceField Publication
