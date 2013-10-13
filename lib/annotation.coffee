@Annotations = new Meteor.Collection 'Annotations', transform: (doc) => new @Annotation doc

class @Annotation extends Document
  # created: timestamp of this version
  # author:
  #   username: author's username
  #   fullName: authors' full name
  #   id: author's id
  # body: annotation's body
  # publication: publication's id
  # location:
  #   page: one-based
  #   start: start index of text layer elements of the annotation's highlight (inclusive)
  #   end: end index of text layer elements of the annotation's highlight (inclusive)
