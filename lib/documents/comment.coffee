class @Comment extends Document
  # createdAt: timestamp when document was created
  # updatedAt: timestamp of this version
  # author:
  #   _id: author's person id
  #   slug: author's person id
  #   givenName
  #   familyName
  #   gravatarHash
  #   user
  #     username
  # annotation
  #   _id
  # publication
  #   _id
  # body: in HTML (inline, no block elements)
  # license: license information, if known

  @Meta
    name: 'Comment'
    fields: =>
      author: @ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username']
      annotation: @ReferenceField Annotation
      publication: @ReferenceField Publication

  hasReadAccess: (person) =>
    throw new Error "Not needed, documents are public"

  @requireReadAccessSelector: (person, selector) ->
    throw new Error "Not needed, documents are public"

  @readAccessPersonFields: ->
    throw new Error "Not needed, documents are public"

  @readAccessSelfFields: ->
    throw new Error "Not needed, documents are public"

  hasMaintainerAccess: (person) =>
    # User has to be logged in
    return false unless person?._id

    return true if person.isAdmin

    # TODO: Implement karma points for public documents

    return true if @author._id is person._id

    return false

  @requireMaintainerAccessSelector: (person, selector) ->
    unless person?._id
      # Returns a selector which does not match anything
      return _id:
        $in: []

    return selector if person.isAdmin

    # To not modify input
    selector = EJSON.clone selector

    # We use $and to not override any existing selector field
    selector.$and = [] unless selector.$and

    selector.$and.push
      'author._id': person._id
    selector

  hasAdminAccess: (person) =>
    throw new Error "Not implemented"

  @requireAdminAccessSelector: (person, selector) ->
    throw new Error "Not implemented"

  hasRemoveAccess: (person) =>
    @hasMaintainerAccess person

  @requireRemoveAccessSelector: (person, selector) ->
    @requireMaintainerAccessSelector person, selector

  @applyDefaultAccess: (personId, document) ->
    document
