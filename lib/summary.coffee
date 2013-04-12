Summaries = new Meteor.Collection 'Summaries', transform: (doc) -> new Summary doc

class Summary extends Document
  # created: timestamp of this version
  # author:
  #   username: author's username
  #   id: author's id
  # body: summary's body
  # publication: publication's id
  # paragraph: paragraph's id (index in list of paragraphs)
