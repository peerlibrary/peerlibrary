Annotations = new Meteor.Collection 'Annotations', transform: (doc) => new @Annotation doc

class Annotation extends @Document
  # created: timestamp of this version
  # author:
  #   username: author's username
  #   fullName: authors' full name
  #   id: author's id
  # body: annotation's body
  # publication: publication's id
  # location:
  #   page: one-based
  #   left: left coordinate
  #   top: top coordinate
  #   width: width of the annotation's location
  #   height: height of the annotation's location

@Annotations = Annotations
@Annotation = Annotation