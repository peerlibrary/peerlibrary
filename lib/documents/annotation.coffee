class @Annotation extends Document
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
  # access: 0 (private), 1 (public)
  # readUsers: if private access, list of users who have read permissions
  # readGroups: if private access, list of groups who have read permissions
  # body: annotation's body
  # publication:
  #   _id: publication's id
  # highlights: list of
  #   _id: highlight id
  # local (client only): is this annotation just a temporary annotation on the cliend side

  @Meta
    name: 'Annotation'
    fields: =>
      author: @ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username']
      readUsers: [@ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username']]
      readGroups: [@ReferenceField Group, ['slug', 'name']]
      publication: @ReferenceField Publication
      highlights: [@ReferenceField Highlight, [], true, 'annotations']

  @ACCESS:
    PRIVATE: 0
    PUBLIC: 1
