@Persons = new Meteor.Collection 'Persons', transform: (doc) => new @Person doc

class @Person extends @Document
  # user: (null if unregistered)
  #   id
  #   username
  # slug: unique slug for URL
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
  #   thesis: publication id
  #   advisor: person id
  #   startYear
  #   endYear: null if ongoing
  #   completed: true if degree granted
  # publications: list of authored publication ids
