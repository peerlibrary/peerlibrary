class @Collection extends Document
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
  # name: the name of the collection
  # slug: unique slug for URL
  # publications: list of
  #   _id: publication's id

  @Meta
    name: 'Collection'
    fields: =>
      slug: @GeneratedField 'self', ['name']
      author: @ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username']
      publications: [@ReferenceField Publication]