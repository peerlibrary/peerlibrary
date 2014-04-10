class @Annotation extends AccessDocument
  # access: 0 (private), 1 (public)
  # readPersons: if private access, list of persons who have read permissions
  # readGroups: if private access, list of groups who have read permissions
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
      publication: @ReferenceField Publication, [], true, 'annotations'
      highlights: [@ReferenceField Highlight, [], true, 'annotations']
