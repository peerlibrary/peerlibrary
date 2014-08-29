EMAIL_FIELDS =
  'user.emails': 1

class @Person extends AccessDocument
  # maintainerPersons: list of persons who have maintainer permissions
  # maintainerGroups: list of groups who have maintainer permissions
  # adminPersons: list of persons who have admin permissions
  # adminGroups: list of groups who have admin permissions
  # createdAt: timestamp when document was created
  # updatedAt: timestamp of this version
  # lastActivity: time of the last user site activity (authored anything, voted on anything, etc.)
  # user: (null if without user account)
  #   _id
  #   emails: list with first element of user's e-mail
  #   username
  # slug: unique slug for URL
  # gravatarHash: hash for Gravatar
  # givenName
  # familyName
  # displayName: combination of givenName, familyName, user.username, email, and slug
  # invitedEmail (client only): e-mail address of the user, used only to provide it to inviters of a given person
  # isAdmin: boolean, is user an administrator or not
  # invited: list of
  #   by: a person who invited this person
  #     _id
  #   message: optional message for invitation email, can be a string, or an object representing the source of invitation:
  #     route: route name
  #     params: list or object of parameters for the route
  # inGroups: list of (reverse field from Group.members)
  #   _id: id of a group the person is in
  # publications: list of (reverse field from Publication.authors)
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
      maintainerPersons: [@ReferenceField 'self', ['slug', 'displayName', 'gravatarHash', 'user.username']]
      maintainerGroups: [@ReferenceField Group, ['slug', 'name']]
      adminPersons: [@ReferenceField 'self', ['slug', 'displayName', 'gravatarHash', 'user.username']]
      adminGroups: [@ReferenceField Group, ['slug', 'name']]
      user: @ReferenceField User, [emails: {$slice: 1}, 'username'], false
      slug: @GeneratedField 'self', ['user.username']
      displayName: @GeneratedField 'self', ['givenName', 'familyName', 'user.username', 'slug'].concat(_.keys EMAIL_FIELDS)
      library: [@ReferenceField Publication]
      gravatarHash: @GeneratedField User, [emails: {$slice: 1}, 'person']
      invited: [
        by: @ReferenceField 'self', [], false
      ]
    # We are using publications in updatedAt trigger, because it is part of person's metadata, but this means
    # that it also updates lastActivity, so we do not need to have a trigger in Publication for authors field
    triggers: =>
      # We do not want only to update updateAt when user._id changes, but also emails and username, so we trigger for the whole user field
      updatedAt: UpdatedAtTrigger ['user', 'givenName', 'familyName', 'publications._id']
      lastActivity: LastActivityTrigger ['library._id']
      personLastActivity: RelatedLastActivityTrigger Person, ['invited.by._id'], (doc, oldDoc) ->
        oldInvited = _.pluck _.pluck(oldDoc?.invited, 'by'), '_id'
        newInvited = _.pluck _.pluck(doc?.invited, 'by'), '_id'
        _.difference newInvited, oldInvited
      # TODO: For now we are updating last activity of all publications in a library, but we might consider removing this and leave it to the "trending" view
      publicationsLastActivity: RelatedLastActivityTrigger Publication, ['library._id'], (doc, oldDoc) ->
        newPublications = (publication._id for publication in doc.library or [])
        oldPublications = (publication._id for publication in oldDoc.library or [])
        _.difference newPublications, oldPublications

  @verboseNamePlural: ->
    "people"

  @PUBLISH_CATALOG_SORT:
    [
      name: "last activity"
      sort: [
        ['lastActivity', 'desc']
      ]
    ,
      name: "join date (newest first)"
      sort: [
        ['createdAt', 'desc']
      ]
    ,
      name: "join date (oldest first)"
      sort: [
        ['createdAt', 'asc']
      ]
    ,
      name: "displayed name"
      # TODO: Sorting by names should be case insensitive
      sort: [
        ['displayName', 'asc']
      ]
    ,
      name: "given name"
      # TODO: Sorting by names should be case insensitive
      sort: [
        ['givenName', 'asc']
        ['familyName', 'asc']
      ]
    ,
      name: "family name"
      # TODO: Sorting by names should be case insensitive
      sort: [
        ['familyName', 'asc']
        ['givenName', 'asc']
      ]
    ,
      name: "username"
      # TODO: Sorting by names should be case insensitive
      sort: [
        ['user', 'desc']
        ['user.username', 'asc']
      ]
    ]

  # Use force if you want the method to compute the value
  # and not use a (possibly obsolete) cached one.
  getDisplayName: (force) =>
    # When used as a template helper, options object is
    # passed in, so let's make sure this is not happening.
    force = false unless _.isBoolean force
    if not force and @displayName
      return @displayName
    else if @givenName and @familyName
      return "#{ @givenName } #{ @familyName }"
    else if @givenName
      return @givenName
    else if @familyName
      return @familyName
    else if @user?.username
      return @user.username
    else if @email()
      return @email()
    # We check displayName again, because we maybe skipped it above
    else if @displayName
      return @displayName
    else
      return @slug

  email: =>
    # TODO: Return e-mail address only if verified, when we will support e-mail verification
    @user?.emails?[0]?.address or @invitedEmail

  @emailFields: ->
    EMAIL_FIELDS

  avatar: (size) =>
    # When used in the template without providing the size, a Handlebars argument is passed in that place (it is always the last argument)
    size = 24 unless _.isNumber size

    defaultAvatar = if @gravatarHash then 'identicon' else Meteor.absoluteUrl 'images/spacer.gif',
      if Meteor.settings?.public?.production then {} else rootUrl: 'https://peerlibrary.org'

    # TODO: We should specify default URL to the image of an avatar which is generated from name initials
    "https://secure.gravatar.com/avatar/#{ @gravatarHash }?s=#{ size }&d=#{ defaultAvatar }"

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
    document = super

    # We need to know _id to be able to add it to adminPersons
    assert document._id

    # TODO: Temporary, while we do not yet have karma points
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
