@Annotations = new Meteor.Collection 'Annotations', transform: (doc) => new @Annotation doc

class @Annotation extends Document
  # created: timestamp when document was created
  # updated: timestamp of this version
  # author:
  #   _id: author's person id
  #   slug: author's person id
  #   foreNames
  #   lastName
  # body: annotation's body
  # publication:
  #   _id: publication's id
  # highlights: list of
  #   _id: highlight id
  # local (client only): is this annotation just a temporary annotation on the cliend side

  # Should be a function so that we can possible resolve circual references
  @Meta =>
    collection: Annotations
    fields:
      author: @ReferenceField Person, ['slug', 'foreNames', 'lastName']
      publication: @ReferenceField Publication
      highlights: [@ReferenceField Highlight]
