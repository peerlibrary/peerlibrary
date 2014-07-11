class @Annotation extends ReadAccessDocument
  # access: 0 (private, ACCESS.PRIVATE), 1 (public, ACCESS.PUBLIC)
  # readPersons: if private access, list of persons who have read permissions
  # readGroups: if private access, list of groups who have read permissions
  # maintainerPersons: list of persons who have maintainer permissions
  # maintainerGroups: list of groups who have maintainer permissions
  # adminPersons: list of persons who have admin permissions
  # adminGroups: list of groups who have admin permissions
  # createdAt: timestamp when document was created
  # updatedAt: timestamp of this version
  # lastActivity: time of the last annotation activity (commenting)
  # author:
  #   _id: person id
  #   slug
  #   displayName
  #   gravatarHash
  # body: in HTML
  # publication:
  #   _id: publication's id
  #   slug
  #   title
  # references: made in the body of the annotation
  #   highlights: list of
  #     _id
  #   annotations: list of
  #     _id
  #   publications: list of
  #     _id
  #     slug
  #     title
  #   persons: list of
  #     _id: person id
  #     slug
  #     displayName
  #     gravatarHash
  #   groups: list of
  #     _id
  #     slug
  #     name
  #   tags: list of
  #     _id
  #     name: ISO 639-1 dictionary
  #     slug: ISO 639-1 dictionary
  #   collections: list of
  #     _id
  #     slug
  #     name
  #   comments: list of
  #     _id
  #   urls: list of
  #     _id
  #     url
  # tags: list of
  #   tag:
  #     _id
  #     name: ISO 639-1 dictionary
  #     slug: ISO 639-1 dictionary
  # comments: list of (reverse field from Comment.annotation)
  #   _id: comment id
  # commentsCount: number of comments for this annotation
  # referencingAnnotations: list of (reverse field from Annotation.references.annotations)
  #   _id: annotation id
  # license: license information, if known
  # inside: list of groups this annotations was made/shared inside
  #   _id
  #   slug
  #   name
  # local (client only): if it exists this is just a temporary annotation on the client side, 1 (automatically created, LOCAL.AUTOMATIC), 2 (user changed the content, LOCAL.CHANGED)
  # editing (client only): is this annotation being edited
  # searchResult (client only): the last search query this document is a result for, if any, used only in search results
  #   _id: id of the query, an _id of the SearchResult object for the query
  #   order: order of the result in the search query, lower number means higher

  @Meta
    name: 'Annotation'
    fields: =>
      maintainerPersons: [@ReferenceField Person, ['slug', 'displayName', 'gravatarHash', 'user.username']]
      maintainerGroups: [@ReferenceField Group, ['slug', 'name']]
      adminPersons: [@ReferenceField Person, ['slug', 'displayName', 'gravatarHash', 'user.username']]
      adminGroups: [@ReferenceField Group, ['slug', 'name']]
      author: @ReferenceField Person, ['slug', 'displayName', 'gravatarHash', 'user.username']
      publication: @ReferenceField Publication, ['slug', 'title'], true, 'annotations'
      references:
        highlights: [@ReferenceField Highlight, [], true, 'referencingAnnotations']
        annotations: [@ReferenceField 'self', [], true, 'referencingAnnotations']
        publications: [@ReferenceField Publication, ['slug', 'title'], true, 'referencingAnnotations']
        persons: [@ReferenceField Person, ['slug', 'displayName', 'gravatarHash'], true, 'referencingAnnotations']
        groups: [@ReferenceField Group, ['slug', 'name'], true, 'referencingAnnotations']
        # TODO: Are we sure that we want a reverse field for tags? This could become a huge list for popular tags.
        tags: [@ReferenceField Tag, ['name', 'slug'], true, 'referencingAnnotations']
        collections: [@ReferenceField Collection, ['slug', 'name'], true, 'referencingAnnotations']
        # TODO: Are we sure that we want a reverse field for urls? This could become a huge list for popular urls.
        comments: [@ReferenceField Comment, [], true, 'referencingAnnotations']
        urls: [@ReferenceField Url, ['url'], true, 'referencingAnnotations']
      tags: [
        tag: @ReferenceField Tag, ['name', 'slug']
      ]
      inside: [@ReferenceField Group, ['slug', 'name']]
      commentsCount: @GeneratedField 'self', ['comments']
    # We do not see referencing something as an event which should update lastActivity of a referenced document.
    # Additionally, we update lastActivity when there is a constructive change, like adding to a group, and not when
    # document is being removed. When value changes we update just the related lastActivity of a new value, not old one.
    triggers: =>
      updatedAt: UpdatedAtTrigger ['author._id', 'body', 'publication._id', 'tags.tag._id', 'license', 'inside._id']
      personLastActivity: RelatedLastActivityTrigger Person, ['author._id'], (doc, oldDoc) -> doc.author?._id
      publicationLastActivity: RelatedLastActivityTrigger Publication, ['publication._id'], (doc, oldDoc) -> doc.publication?._id
      tagsLastActivity: RelatedLastActivityTrigger Tag, ['tags.tag._id'], (doc, oldDoc) ->
        newTags = (tag.tag._id for tag in doc.tags or [])
        oldTags = (tag.tag._id for tag in oldDoc.tags or [])
        _.difference newTags, oldTags
      groupsLastActivity: RelatedLastActivityTrigger Group, ['inside._id'], (doc, oldDoc) ->
        newGroups = (group._id for group in doc.inside or [])
        oldGroups = (group._id for group in oldDoc.inside or [])
        _.difference newGroups, oldGroups

  @PUBLISH_CATALOG_SORT:
    [
      name: "last activity"
      sort: [
        ['lastActivity', 'desc']
      ]
    ,
      name: "author"
      # TODO: Sorting by names should be case insensitive
      sort: [
        ['author.displayName', 'asc']
      ]
    ,
      name: "comments"
      sort: [
        ['commentsCount', 'desc']
      ]
    ]

  _hasMaintainerAccess: (person) =>
    # User has to be logged in
    return unless person?._id

    # TODO: Implement karma points for public documents

    return true if @author._id is person._id

    return true if person._id in _.pluck @maintainerPersons, '_id'

    personGroups = _.pluck person.inGroups, '_id'
    documentGroups = _.pluck @maintainerGroups, '_id'

    return true if _.intersection(personGroups, documentGroups).length

  @_requireMaintainerAccessConditions: (person) ->
    return [] unless person?._id

    [
      'author._id': person._id
    ,
      'maintainerPersons._id': person._id
    ,
      'maintainerGroups._id':
        $in: _.pluck person.inGroups, '_id'
    ]

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

  @defaultAccess: ->
    @ACCESS.PRIVATE

  @applyDefaultAccess: (personId, document) ->
    document = super

    if personId and personId not in _.pluck document.adminPersons, '_id'
      document.adminPersons ?= []
      document.adminPersons.push
        _id: personId

    if document.author?._id and document.author._id not in _.pluck document.adminPersons, '_id'
      document.adminPersons ?= []
      document.adminPersons.push
        _id: document.author._id

    # Grant read access to all groups inside which this annotation was shared
    document.inside ?= []
    document.inside.forEach (group, index) ->
      if group._id not in _.pluck document.readGroups, '_id'
        document.readGroups ?= []
        document.readGroups.push
          _id: group._id

    document
