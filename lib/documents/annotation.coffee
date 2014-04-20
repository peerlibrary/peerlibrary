class @Annotation extends AccessDocument
  # access: 0 (private, ACCESS.PRIVATE), 1 (public, ACCESS.PUBLIC)
  # readPersons: if private access, list of persons who have read permissions
  # readGroups: if private access, list of groups who have read permissions
  # maintainerPersons: list of persons who have maintainer permissions
  # maintainerGroups: ilist of groups who have maintainer permissions
  # adminPersons: list of persons who have admin permissions
  # adminGroups: ilist of groups who have admin permissions
  # createdAt: timestamp when document was created
  # updatedAt: timestamp of this version
  # author:
  #   _id: person id
  #   slug
  #   givenName
  #   familyName
  #   gravatarHash
  #   user
  #     username
  # body: in HTML
  # publication:
  #   _id: publication's id
  # references: made in the body of annotation or comments
  #   highlights: list of
  #     _id
  #   annotations: list of
  #     _id
  #   publications: list of
  #     _id
  #     slug
  #     title
  #   persons: list of
  #     _id
  #     slug
  #     givenName
  #     familyName
  #     gravatarHash
  #     user
  #       username
  #   tags: list of
  #     _id
  #     name: ISO 639-1 dictionary
  #     slug: ISO 639-1 dictionary
  # tags: list of
  #   tag:
  #     _id
  #     name: ISO 639-1 dictionary
  #     slug: ISO 639-1 dictionary
  # referencingAnnotations: list of (reverse field from Annotation.references.annotations)
  #   _id: annotation id
  # license: license information, if known
  # local (client only): is this annotation just a temporary annotation on the client side
  # editing (client only): is this annotation being edited

  @Meta
    name: 'Annotation'
    fields: =>
      maintainerPersons: [@ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username']]
      maintainerGroups: [@ReferenceField Group, ['slug', 'name']]
      adminPersons: [@ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username']]
      adminGroups: [@ReferenceField Group, ['slug', 'name']]
      author: @ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username']
      publication: @ReferenceField Publication, [], true, 'annotations'
      references:
        highlights: [@ReferenceField Highlight, [], true, 'referencingAnnotations']
        annotations: [@ReferenceField 'self', [], true, 'referencingAnnotations']
        publications: [@ReferenceField Publication, ['slug', 'title'], true, 'referencingAnnotations']
        persons: [@ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username'], true, 'referencingAnnotations']
        # TODO: Are we sure that we want a reverse field for tags? This could become a huge list for popular tags.
        tags: [@ReferenceField Tag, ['name', 'slug'], true, 'referencingAnnotations']
      tags: [
        tag: @ReferenceField Tag, ['name', 'slug']
      ]

  hasMaintainerAccess: (person) =>
    # User has to be logged in
    return false unless person?._id

    return true if person.isAdmin

    # Unknown access, we prevent access to the document
    # TODO: Should we log this?
    return false unless @access in [Annotation.ACCESS.PUBLIC, Annotation.ACCESS.PRIVATE]

    # TODO: Implement maintainer karma points for public documents

    return true if @author._id is person._id

    return true if person._id in _.pluck @maintainerPersons, '_id'

    personGroups = _.pluck person.inGroups, '_id'
    documentGroups = _.pluck @maintainerGroups, '_id'

    return true if _.intersection(personGroups, documentGroups).length

    # TODO: Implement admin karma points for public documents

    return true if person._id in _.pluck @adminPersons, '_id'

    documentGroups = _.pluck @adminGroups, '_id'

    return true if _.intersection(personGroups, documentGroups).length

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

    accessConditions = [
      'author._id': person._id
    ,
      'maintainerPersons._id': person._id
    ,
      'maintainerGroups._id':
        $in: _.pluck person.inGroups, '_id'
    ,
      'adminPersons._id': person._id
    ,
      'adminGroups._id':
        $in: _.pluck person.inGroups, '_id'
    ]

    selector.$and.push
      access:
        $in: [Annotation.ACCESS.PUBLIC, Annotation.ACCESS.PRIVATE]
      $or: accessConditions
    selector

  hasAdminAccess: (person) =>
    # User has to be logged in
    return false unless person?._id

    return true if person.isAdmin

    # Unknown access, we prevent access to the document
    # TODO: Should we log this?
    return false unless @access in [Annotation.ACCESS.PUBLIC, Annotation.ACCESS.PRIVATE]

    # TODO: Implement karma points for public publications

    return true if person._id in _.pluck @adminPersons, '_id'

    personGroups = _.pluck person.inGroups, '_id'
    documentGroups = _.pluck @adminGroups, '_id'

    return true if _.intersection(personGroups, documentGroups).length

    return false

  @requireAdminAccessSelector: (person, selector) ->
    unless person?._id
      # Returns a selector which does not match anything
      return _id:
        $in: []

    return selector if person.isAdmin

    # To not modify input
    selector = EJSON.clone selector

    # We use $and to not override any existing selector field
    selector.$and = [] unless selector.$and

    accessConditions = [
      'adminPersons._id': person._id
    ,
      'adminGroups._id':
        $in: _.pluck person.inGroups, '_id'
    ]

    selector.$and.push
      access:
        $in: [Annotation.ACCESS.PUBLIC, Annotation.ACCESS.PRIVATE]
      $or: accessConditions
    selector

  hasRemoveAccess: (person) =>
    @hasMaintainerAccess person

  @requireRemoveAccessSelector: (person, selector) ->
    @requireMaintainerAccessSelector person, selector

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

    document