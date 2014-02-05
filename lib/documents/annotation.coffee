@Annotations = new Meteor.Collection 'Annotations', transform: (doc) => new @Annotation doc

class @Annotation extends Document
  # created: timestamp when document was created
  # updated: timestamp of this version
  # author:
  #   _id: author's person id
  #   slug: author's person id
  #   givenName
  #   familyName
  #   gravatarHash
  # body: annotation's body
  # publication:
  #   _id: publication's id
  # highlights: list of
  #   _id: highlight id
  # labels: list of
  #   tag:
  #     _id: label's tag id
  #     name: label's tag name (ISO 639-1 dictionary)
  #     slug: labels' tag slug
  #   upvoters: list of
  #     _id: upvoter's person id
  #   downvoters: list of
  #     _id: upvoter's person id
  # upvoters: list of
  #   _id: upvoter's person id
  # downvoters: list of
  #   _id: downvoter's person id
  # local (client only): is this annotation just a temporary annotation on the client side

  # Should be a function so that we can possible resolve circual references
  @Meta =>
    collection: Annotations
    fields:
      author: @ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash']
      publication: @ReferenceField Publication
      highlights: [@ReferenceField Highlight]
      labels: [
        tag: @ReferenceField Tag, ['name', 'slug']
        upvoters: @ReferenceField Person
        downvoters: @ReferenceField Person
      ]
      upvoters: @ReferenceField Person
      downvoters: @ReferenceField Person
