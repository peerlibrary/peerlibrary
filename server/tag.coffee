SLUG_MAX_LENGTH = 80

class @Tag extends Tag
  @Meta
    name: 'Tag'
    replaceParent: true
    fields: (fields) =>
      fields.slug.generator = (fields) ->
        if fields.name
          for language, name of fields.name
            fields.name[language] = URLify2 name, SLUG_MAX_LENGTH
          [fields._id, fields.name]
        else
          [fields._id, '']
      fields

  # A set of fields which are public and can be published to the client
  @PUBLIC_FIELDS: ->
    fields: {} # All

Meteor.publish 'tag-by-id', (tagId) ->
  check tagId, DocumentId

  Tag.documents.find
    _id: tagId
  ,
    Tag.PUBLIC_FIELDS()
