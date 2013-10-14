@Persons = new Meteor.Collection 'Persons', transform: (doc) => new @Person doc

class @Person extends Document
  # user: (null if unregistered)
  #   _id
  #   username
  # slug: unique slug for URL
  # gravatarHash: hash for Gravatar
  # created: creation timestamp
  # foreNames
  # lastName
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
  #   _id: authored publication's id

  # Should be a function so that we can redefine later on
  @Meta =>
    collection: Persons
    fields:
      user: @Reference User, ['username'], false
      publications: [@Reference Publication]
