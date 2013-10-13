@Annotations = new Meteor.Collection 'Annotations', transform: (doc) => new @Annotation doc

class @Annotation extends Document
  # created: timestamp of this version
  # author:
  #   _id: author's person id
  #   slug: author's person id
  #   foreNames
  #   lastName
  # body: annotation's body
  # publication:
  #   _id: publication's id
  # location:
  #   page: one-based
  #   start: start index of text layer elements of the annotation's highlight (inclusive)
  #   end: end index of text layer elements of the annotation's highlight (inclusive)

  @Meta
    collection: Publications
    fields:
      author: @Reference Person, ['slug', 'foreNames', 'lastName']
      publication: @Reference Publication
