@Annotations = new Meteor.Collection 'Annotations', transform: (doc) => new @Annotation doc

class @Annotation extends Document
  # created: timestamp when document was created
  # updated: timestamp of this version
  # author:
  #   _id: person id
  #   slug
  #   givenName
  #   familyName
  #   gravatarHash
  # body: annotation's body
  # publication:
  #   _id
  # references: made in the body
  #   highlights: list of
  #     _id
  #   annotations: list of
  #     _id
  #   publications: list of
  #     _id
  #     slug
  #     title
  #   persons: list of
  #     _id
  #     slug
  #     givenName
  #     familyName
  #   tags: list of
  #     _id
  #     name: ISO 639-1 dictionary
  #     slug: ISO 639-1 dictionary
  # tags: list of
  #   tag:
  #     _id
  #     name: ISO 639-1 dictionary
  #     slug: ISO 639-1 dictionary
  #   upvoters: list of
  #     _id: person id
  #   downvoters: list of
  #     _id: person id
  # upvoters: list of
  #   _id: person id
  # downvoters: list of
  #   _id: person id
  # local (client only): is this annotation just a temporary annotation on the client side

  # Should be a function so that we can possible resolve circual references
  @Meta =>
    collection: Annotations
    fields:
      author: @ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash']
      publication: @ReferenceField Publication
      references:
        highlights: [@ReferenceField Highlight]
        annotations: [@ReferenceField 'self']
        publications: [@ReferenceField Publication, ['slug', 'title']]
        persons: [@ReferenceField Person, ['slug', 'givenName', 'familyName']]
        tags: [@ReferenceField Tag]
      tags: [
        tag: @ReferenceField Tag
      ]
