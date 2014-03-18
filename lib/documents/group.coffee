class @Group extends Document
  # createdAt: timestamp when document was created
  # updatedAt: timestamp of this version
  # slug: slug for URL
  # name: name of the group
  # members: list of people in the group
  # membersCount: number of people in the group

  @Meta
    name: 'Group'
    fields: =>
      slug: @GeneratedField 'self', ['name']
      members: [@ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username']]
      membersCount: @GeneratedField 'self', ['members']
