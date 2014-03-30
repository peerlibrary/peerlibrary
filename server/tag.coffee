class @Tag extends Tag
  @Meta
    name: 'Tag'
    replaceParent: true
    fields: (fields) =>
      fields.slug.generator = (fields) ->
        # TODO: generate slugs
        fields
      fields

  # A set of fields which are public and can be published to the client
  @PUBLIC_FIELDS: ->
    fields: {} # All

Tag.Meta.collection.allow
  insert: (userId, doc) ->
    # TODO: Check whether inserted document conforms to schema
    # TODO: Check the target (try to apply it on the server)
    # TODO: Check that author really has access to the publication

    userId

  update: (userId, doc) -> false

  remove: (userId, doc) -> false

Meteor.publish 'tag-by-id', (tagId) ->
  check tagId, String

  return unless tagId

  Tag.documents.find
    _id: tagId
  ,
    Tag.PUBLIC_FIELDS()
