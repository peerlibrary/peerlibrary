class @User extends BaseDocument
  # createdAt: time of creation
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
