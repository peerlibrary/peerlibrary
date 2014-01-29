@Persons = new Meteor.Collection 'Persons', transform: (doc) => new @Person doc

class @Person extends Document
  # user: (null if without user account)
  #   _id
  #   username
  # slug: unique slug for URL
  # gravatarHash: hash for Gravatar
  # created: timestamp when document was created
  # givenName
  # familyName
  # isAdmin: boolean, is user an administrator or not
  # publications: list of
  #   _id: authored publication id
  # library: list of
  #   _id: added publication id

  # Should be a function so that we can possible resolve circual references
  @Meta =>
    collection: Persons
    fields:
      user: @ReferenceField User, ['username'], false
      publications: [@ReferenceField Publication]
      library: [@ReferenceField Publication]
      slug: @GeneratedField 'self', ['user.username']
      gravatarHash: @GeneratedField User, [emails: {$slice: 1}, 'person']

Meteor.person = (userId) ->
  # Meteor.userId is reactive
  userId ?= Meteor.userId()

  return null unless userId

  Persons.findOne
    'user._id': userId

Meteor.personId = (userId) ->
  # Meteor.userId is reactive
  userId ?= Meteor.userId()

  return null unless userId

  person = Persons.findOne
    'user._id': userId
  ,
    _id: 1

  person?._id or null
