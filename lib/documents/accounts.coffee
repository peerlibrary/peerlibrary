# This document is a special case because Meteor.users collection is not really returning
# instances of User class but normal documents, which seems good enough for now. We have
# this document defined so that we can define references against it.

class @User extends Document
  # createdAt: time of creation
  # username: user's username
  # emails: list of
  #   address: e-mail address
  #   verified: is e-mail address verified
  # services: list of authentication/linked services
  # person:
  #   _id: id of related person document

  # Should be a function so that we can possible resolve circual references
  @Meta =>
    collection: Meteor.users
    fields:
      person: @ReferenceField Person
