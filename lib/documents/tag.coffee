@Tags = new Meteor.Collection 'Tags', transform: (doc) => new @Tag doc

class @Tag extends Document
  # created: timestamp when tag was created
  # name:
  #   en: name of the tag in English (ISO 639-1)
  # slug:
  #   en: slug of the tag in English (ISO 639-1)

  # Should be a function so that we can possible resolve circual references
  @Meta =>
   collection: Tags
   fields:
     slug: @GeneratedField 'self', ['name']
