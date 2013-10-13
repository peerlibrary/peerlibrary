class @User extends Document
  # createdAt: time of creation
  # username: user's username
  # emails: list of
  #   address: e-mail address
  #   verified: is e-mail address verified
  # services: list of authentication/linked services
  # profile:
  #   _id: id of related profile document

  @Meta
    collection: Meteor.users
    fields:
      profiles: @Reference Profile
