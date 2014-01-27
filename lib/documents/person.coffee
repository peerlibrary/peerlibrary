@Persons = new Meteor.Collection 'Persons', transform: (doc) => new @Person doc

class @Person extends Document
  # user: (null if without user account)
  #   _id
  #   username
  # slug: unique slug for URL
  # gravatarHash: hash for Gravatar
  # created: creation timestamp
  # foreNames
  # lastName
  # isAdmin: boolean, is user an administrator or not
  # work
  #   position (e.g. Professor of Theoretical Physics)
  #   institution (e.g. University of California, Berkeley)
  #   startYear (e.g. 2011)
  #   endYear null if current
  # education
  #   degree (e.g. PhD)
  #   concentration (e.g. Social Anthropology)
  #   institution
  #   thesis: publication id - TODO: Define reference
  #   advisor: person id - TODO: Define reference
  #   startYear
  #   endYear: null if ongoing
  #   completed: true if degree granted
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
