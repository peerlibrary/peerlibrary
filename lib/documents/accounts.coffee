class @User extends Document
  # createdAt: time of creation
  # updatedAt: time of last change
  # username: user's username
  # emails: list of
  #   address: e-mail address
  #   verified: is e-mail address verified
  # services: list of authentication/linked services
  # person:
  #   _id: id of related person document

  @Meta
    name: 'User'
    collection: Meteor.users
    fields: =>
      person: @ReferenceField Person
    triggers: =>
      updatedAt: LastChangedTimestampTrigger ['username', 'emails', 'services', 'person._id']
