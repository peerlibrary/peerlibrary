class @Comment extends AccessDocument
  # createdAt: timestamp when document was created
  # updatedAt: timestamp of this version
  # lastActivity: time of the last comment activity (for now same as updatedAt)
  # author:
  #   _id: author's person id
  #   slug
  #   displayName
  #   gravatarHash
  #   user.username
  # annotation
  #   _id
  # publication
  #   _id
  # body: in HTML (inline, no block elements)
  # license: license information, if known
  # referencingAnnotations: list of (reverse field from Annotation.references.comments)
  #   _id: annotation id

  @Meta
    name: 'Comment'
    fields: =>
      author: @ReferenceField Person, ['slug', 'displayName', 'gravatarHash', 'user.username']
      annotation: @ReferenceField Annotation, [], true, 'comments'
      publication: @ReferenceField Publication
    triggers: =>
      updatedAt: UpdatedAtTrigger ['author._id', 'annotation._id', 'publication._id', 'body', 'license']
      personLastActivity: RelatedLastActivityTrigger Person, ['author._id'], (doc, oldDoc) -> doc.author?._id
      annotationLastActivity: RelatedLastActivityTrigger Annotation, ['annotation._id'], (doc, oldDoc) -> doc.annotation?._id
      publicationLastActivity: RelatedLastActivityTrigger Publication, ['publication._id'], (doc, oldDoc) -> doc.publication?._id

  hasReadAccess: (person) =>
    throw new Error "Not needed, documents are public"

  @requireReadAccessSelector: (person, selector) ->
    throw new Error "Not needed, documents are public"

  @readAccessPersonFields: ->
    throw new Error "Not needed, documents are public"

  @readAccessSelfFields: ->
    throw new Error "Not needed, documents are public"

  _hasMaintainerAccess: (person) =>
    # User has to be logged in
    return unless person?._id

    # TODO: Implement karma points

    return true if @author._id is person._id

  @_requireMaintainerAccessConditions: (person) ->
    return [] unless person?._id

    [
      'author._id': person._id
    ]

  @maintainerAccessPersonFields: ->
    super

  @maintainerAccessSelfFields: ->
    fields = super
    _.extend fields,
      author: 1

  hasAdminAccess: (person) =>
    throw new Error "Not implemented"

  @requireAdminAccessSelector: (person, selector) ->
    throw new Error "Not implemented"
