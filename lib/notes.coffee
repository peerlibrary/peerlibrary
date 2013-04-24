Notes = new Meteor.Collection 'Notes', transform: (doc) -> new Note doc

# We name it Note to be consistent, but for the user we display each Note document as "notes"
class Note extends Document
  # created: timestamp of this version
  # author:
  #   username: author's username
  #   fullName: authors' full name
  #   id: author's id
  # body: notes
  # publication: publication's id
  # paragraph: paragraph's id (index in list of paragraphs)
