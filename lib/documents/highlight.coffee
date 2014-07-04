class @Highlight extends AccessDocument
  # createdAt: timestamp when document was created
  # updatedAt: timestamp of this version
  # lastActivity: time of the last highlight activity (for now same as updatedAt)
  # author:
  #   _id: author's person id
  #   slug: author's person id
  #   givenName
  #   familyName
  #   gravatarHash
  #   user
  #     username
  # publication:
  #   _id: publication's id
  #   slug
  #   title
  # quote: quote made by this highlight
  # target: open annotation standard compatible target information
  # referencingAnnotations: list of (reverse field from Annotation.references.highlights)
  #   _id: annotation id
  # searchResult (client only): the last search query this document is a result for, if any, used only in search results
  #   _id: id of the query, an _id of the SearchResult object for the query
  #   order: order of the result in the search query, lower number means higher

  @Meta
    name: 'Highlight'
    fields: =>
      author: @ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username']
      publication: @ReferenceField Publication, ['slug', 'title']
    triggers: =>
      updatedAt: UpdatedAtTrigger ['author._id', 'publication._id', 'quote', 'target']
      personLastActivity: RelatedLastActivityTrigger Person, ['author._id'], (doc, oldDoc) -> doc.author?._id
      publicationLastActivity: RelatedLastActivityTrigger Publication, ['publication._id'], (doc, oldDoc) -> doc.publication?._id

  @PUBLISH_CATALOG_SORT:
    [
      name: "last activity"
      sort: [
        ['updatedAt', 'desc']
      ]
    ,
      name: "author"
      sort: [
        ['author', 'asc']
      ]
    ]

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
