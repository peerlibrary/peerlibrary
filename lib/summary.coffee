Summaries = new Meteor.Collection 'Summaries', transform: (doc) -> new Summary doc

class Summary extends Document
  # updated: last change timestamp
  # body: summary's body
  # publication: publication's id
  # paragraph: paragraph's id (index in list of paragraphs)
