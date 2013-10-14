class @User extends Document
  # createdAt: time of creation
  # username: user's username
  # emails: list of
  #   address: e-mail address
  #   verified: is e-mail address verified
  # services: list of authentication/linked services
  # person:
  #   _id: id of related person document

  # Should be a function so that we can redefine later on
  @Meta =>
    collection: Meteor.users
    fields:
      person: @Reference Person
