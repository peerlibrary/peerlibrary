Comments = new Meteor.Collection 'Comments', transform: (doc) -> new Comment doc

class Comment extends Document
  # created: creation timestamp
  # author:
  #   username: author's username
  #   fullName: authors' full name
  #   id: author's id
  # body: comment's body
  # parent: parent's comment id or null if top-level, only one level of nesting is allowed
  # publication: publication's id
  # paragraph: paragraph's id (index in list of paragraphs)
