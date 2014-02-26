@Highlights = new Meteor.Collection 'Highlights', transform: (doc) => new @Highlight doc

class @Highlight extends Document
  # created: timestamp when document was created
  # updated: timestamp of this version
  # author:
  #   _id: author's person id
  #   slug: author's person id
  #   givenName
  #   familyName
  # publication:
  #   _id: publication's id
  # quote: quote made by this highlight
  # target: open annotation standard compatible target information
  # annotations: list of
  #   _id: annotation id

  # Should be a function so that we can possible resolve circual references
  @Meta =>
    collection: Highlights
    fields:
      author: @ReferenceField Person, ['slug', 'givenName', 'familyName']
      publication: @ReferenceField Publication
      annotations: [@ReferenceField Annotation]
