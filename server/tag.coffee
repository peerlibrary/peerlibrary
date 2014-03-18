class @Tag extends Tag
  @Meta
    name: 'Tag'
    replaceParent: true
    fields: (fields) =>
      fields.slug.generator = (fields) ->
        # TODO: generate slugs
        fields
      fields

Tag.Meta.collection.allow
  insert: (userId, doc) ->
    # TODO: Check whether inserted document conforms to schema
    # TODO: Check the target (try to apply it on the server)
    # TODO: Check that author really has access to the publication

    userId

  update: (userId, doc) -> false

  remove: (userId, doc) -> false

