class @Collection extends BasicAccessDocument
  # access: 0 (private, ACCESS.PRIVATE), 1 (public, ACCESS.PUBLIC)
  # readPersons: if private access, list of persons who have read permissions
  # readGroups: if private access, list of groups who have read permissions
  # maintainerPersons: list of persons who have maintainer permissions
  # maintainerGroups: list of groups who have maintainer permissions
  # adminPersons: list of persons who have admin permissions
  # adminGroups: list of groups who have admin permissions
  # createdAt: timestamp when document was created
  # updatedAt: timestamp of this version
  # lastActivity: time of the last collection activity (for now same as updatedAt)
  # authorPerson:
  #   _id: author's person id
  #   slug
  #   displayName
  #   gravatarHash
  #   user.username
  # authorGroup:
  #   _id: author's group id
  #   slug
  #   name
  # authorName: either authorPerson.displayName or authorGroup.name
  # name: the name of the collection
  # slug: unique slug for URL
  # publications: list of
  #   _id: publication's id
  # publicationsCount: number of publications in this collection
  # referencingAnnotations: list of (reverse field from Annotation.references.collections)
  #   _id: annotation id
  # searchResult (client only): the last search query this document is a result for, if any, used only in search results
  #   _id: id of the query, an _id of the SearchResult object for the query
  #   order: order of the result in the search query, lower number means higher

  @Meta
    name: 'Collection'
    fields: =>
      maintainerPersons: [@ReferenceField Person, ['slug', 'displayName', 'gravatarHash', 'user.username']]
      maintainerGroups: [@ReferenceField Group, ['slug', 'name']]
      adminPersons: [@ReferenceField Person, ['slug', 'displayName', 'gravatarHash', 'user.username']]
      adminGroups: [@ReferenceField Group, ['slug', 'name']]
      authorPerson: @ReferenceField Person, ['slug', 'displayName', 'gravatarHash', 'user.username'], false
      authorGroup: @ReferenceField Group, ['slug', 'name'], false
      authorName: @GeneratedField 'self', ['authorPerson', 'authorGroup']
      slug: @GeneratedField 'self', ['name']
      publications: [@ReferenceField Publication]
      publicationsCount: @GeneratedField 'self', ['publications']
    triggers: =>
      updatedAt: UpdatedAtTrigger ['authorPerson._id', 'authorGroup._id', 'name', 'publications._id']
      personLastActivity: RelatedLastActivityTrigger Person, ['authorPerson._id'], (doc, oldDoc) -> doc.authorPerson?._id
      groupLastActivity: RelatedLastActivityTrigger Group, ['authorGroup._id'], (doc, oldDoc) -> doc.authorGroup?._id
      # TODO: For now we are updating last activity of all publications in a collection, but we might consider removing this and leave it to the "trending" view
      publicationsLastActivity: RelatedLastActivityTrigger Publication, ['publications._id'], (doc, oldDoc) ->
        newPublications = (publication._id for publication in doc.publications or [])
        oldPublications = (publication._id for publication in oldDoc?.publications or [])
        _.difference newPublications, oldPublications

  @PUBLISH_CATALOG_SORT:
    [
      name: "last activity"
      sort: [
        ['lastActivity', 'desc']
      ]
    ,
      name: "name"
      # TODO: Sorting by names should be case insensitive
      sort: [
        ['name', 'asc']
      ]
    ,
      name: "author"
      # TODO: Sorting by names should be case insensitive
      sort: [
        ['authorName', 'asc']
        ['name', 'asc']
      ]
    ,
      name: "publications"
      sort: [
        ['publicationsCount', 'desc']
      ]
    ]

  _hasMaintainerAccess: (person) =>
    # User has to be logged in
    return unless person?._id

    # TODO: Implement karma points for public documents

    return true if @authorPerson?._id is person._id

    personGroups = _.pluck person.inGroups, '_id'

    return true if @authorGroup?._id in personGroups

    return true if person._id in _.pluck @maintainerPersons, '_id'

    documentGroups = _.pluck @maintainerGroups, '_id'

    return true if _.intersection(personGroups, documentGroups).length

  @_requireMaintainerAccessConditions: (person, selector) ->
    return [] unless person?._id

    [
      'authorPerson._id': person._id
    ,
      'authorGroup._id':
        $in: _.pluck person.inGroups, '_id'
    ,
      'maintainerPersons._id': person._id
    ,
      'maintainerGroups._id':
        $in: _.pluck person.inGroups, '_id'
    ]

  @maintainerAccessPersonFields: ->
    fields = super
    _.extend fields,
      inGroups: 1

  @maintainerAccessSelfFields: ->
    fields = super
    _.extend fields,
      authorPerson: 1
      authorGroup: 1
      maintainerPersons: 1
      maintainerGroups: 1

  _hasAdminAccess: (person) =>
    # User has to be logged in
    return unless person?._id

    # TODO: Implement karma points for public documents

    return true if person._id in _.pluck @adminPersons, '_id'

    personGroups = _.pluck person.inGroups, '_id'
    documentGroups = _.pluck @adminGroups, '_id'

    return true if _.intersection(personGroups, documentGroups).length

  @_requireAdminAccessConditions: (person) ->
    return [] unless person?._id

    [
      'adminPersons._id': person._id
    ,
      'adminGroups._id':
        $in: _.pluck person.inGroups, '_id'
    ]

  @adminAccessPersonFields: ->
    fields = super
    _.extend fields,
      inGroups: 1

  @adminAccessSelfFields: ->
    fields = super
    _.extend fields,
      adminPersons: 1
      adminGroups: 1

  @applyDefaultAccess: (personId, document) ->
    document = super

    if document.authorPerson?._id and document.authorPerson._id not in _.pluck document.adminPersons, '_id'
      document.adminPersons ?= []
      document.adminPersons.push
        _id: document.authorPerson._id

    if document.authorGroup?._id and document.authorGroup._id not in _.pluck document.adminGroups, '_id'
      document.adminGroups ?= []
      document.adminGroups.push
        _id: document.authorGroup._id

    document = @_applyDefaultAccess personId, document

    document
