class @Person extends AccessDocument
  # maintainerPersons: list of persons who have maintainer permissions
  # maintainerGroups: ilist of groups who have maintainer permissions
  # adminPersons: list of persons who have admin permissions
  # adminGroups: ilist of groups who have admin permissions
  # createdAt: timestamp when document was created
  # updatedAt: timestamp of this version
  # user: (null if without user account)
  #   _id
  #   emails: list with first element of user's e-mail
  #   username
  # slug: unique slug for URL
  # gravatarHash: hash for Gravatar
  # givenName
  # familyName
  # isAdmin: boolean, is user an administrator or not
  # invited:
  #   by: a person who invited this person
  #     _id
  #   message: optional message for invitation email
  # inGroups: list of
  #   _id: id of a group the person is in
  # publications: list of
  #   _id: authored publication id
  # library: list of
  #   _id: added publication id
  # referencingAnnotations: list of (reverse field from Annotation.references.persons)
  #   _id: annotation id
  # searchResult (client only): the last search query this document is a result for, if any, used only in search results
  #   _id: id of the query, an _id of the SearchResult object for the query
  #   order: order of the result in the search query, lower number means higher

  @Meta
    name: 'Person'
    fields: =>
      maintainerPersons: [@ReferenceField 'self', ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username']]
      maintainerGroups: [@ReferenceField Group, ['slug', 'name']]
      adminPersons: [@ReferenceField 'self', ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username']]
      adminGroups: [@ReferenceField Group, ['slug', 'name']]
      user: @ReferenceField User, [emails: {$slice: 1}, 'username'], false
      slug: @GeneratedField 'self', ['user.username']
      publications: [@ReferenceField Publication]
      library: [@ReferenceField Publication]
      gravatarHash: @GeneratedField User, [emails: {$slice: 1}, 'person']
      invited:
        by: @ReferenceField 'self', [], false

  displayName: (dontRefetch) =>
    # When used in the template without providing the dontRefetch, a Handlebars argument is passed in that place (it is always the last argument)
    dontRefetch = false unless _.isBoolean dontRefetch
    if @givenName and @familyName
      return "#{ @givenName } #{ @familyName }"
    else if @givenName
      return @givenName
    else if @user?.username
      return @user.username
    else if @email()
      return @email()
    else if not dontRefetch # To prevent infinite loop
      # Maybe we have access to a person document with more fields
      person = @constructor.documents.findOne @_id
      person.slug = @slug unless not person or person.slug
      return person.displayName true if person

    @slug

  @displayNameFields: ->
    _.extend @emailFields(),
      givenName: 1
      familyName: 1
      'user.username': 1
      slug: 1

  email: =>
    # TODO: Return e-mail address only if verified, when we will support e-mail verification
    @user?.emails?[0]?.address

  @emailFields: ->
    'user.emails': 1

  avatar: (size) =>
    # When used in the template without providing the size, a Handlebars argument is passed in that place (it is always the last argument)
    size = 24 unless _.isNumber size
    # TODO: We should specify default URL to the image of an avatar which is generated from name initials
    # TODO: gravatarHash does not appear
    "https://secure.gravatar.com/avatar/#{ @gravatarHash }?s=#{ size }"

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

    return true if @_id is person._id

    return true if person._id in _.pluck @maintainerPersons, '_id'

    personGroups = _.pluck person.inGroups, '_id'
    documentGroups = _.pluck @maintainerGroups, '_id'

    return true if _.intersection(personGroups, documentGroups).length

  @_requireMaintainerAccessConditions: (person) ->
    return [] unless person?._id

    [
      _id: person._id
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
      maintainerPersons: 1
      maintainerGroups: 1

  _hasAdminAccess: (person) =>
    # User has to be logged in
    return unless person?._id

    # TODO: Implement karma points

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

  hasRemoveAccess: (person) =>
    @hasAdminAccess person

  @requireRemoveAccessSelector: (person, selector) ->
    @requireAdminAccessSelector person, selector

  @removeAccessPersonFields: ->
    @adminAccessPersonFields()

  @removeAccessSelfFields: ->
    @adminAccessSelfFields()

  @applyDefaultAccess: (personId, document) ->
    # We need to know _id to be able to add it to adminPersons
    assert document._id

    if personId and personId not in _.pluck document.adminPersons, '_id'
      document.adminPersons ?= []
      document.adminPersons.push
        _id: personId
    if document._id not in _.pluck document.adminPersons, '_id'
      document.adminPersons ?= []
      document.adminPersons.push
        _id: document._id

    document

Meteor.person = (userId, fields) ->
  if not fields and _.isObject userId
    fields = userId
    userId = null

  # Meteor.userId is reactive
  userId ?= Meteor.userId()
  fields ?= {}

  return null unless userId

  Person.documents.findOne
    'user._id': userId
  ,
    fields: fields

Meteor.personId = (userId) ->
  # Meteor.userId is reactive
  userId ?= Meteor.userId()

  return null unless userId

  person = Person.documents.findOne
    'user._id': userId
  ,
    fields:
      _id: 1

  person?._id or null
