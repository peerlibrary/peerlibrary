accessDocuments = {}

# Registers documents for which we want to support generic grant and revoke methods
@registerForAccess = (document) ->
  assert document.prototype instanceof ReadAccessDocument

  accessDocuments[document.Meta._name] = document

RegisteredForAccess = Match.Where (documentName) ->
  check documentName, String
  accessDocuments.hasOwnProperty documentName

createNotInSetQuery = (documentId, set, personOrGroupName, personOrGroupId) ->
  query =
    _id: documentId

  query["#{set}#{personOrGroupName}s._id"] =
    $ne: personOrGroupId

  query

createAddToSetCommand = (set, personOrGroupName, personOrGroupId) ->
  command =
    $addToSet: {}

  command.$addToSet["#{set}#{personOrGroupName}s"] =
    _id: personOrGroupId

  command

createInSetQuery = (documentId, set, personOrGroupName, personOrGroupId) ->
  query =
    _id: documentId

  query["#{set}#{personOrGroupName}s._id"] = personOrGroupId

  query

createRemoveFromSetCommand = (set, personOrGroupName, personOrGroupId) ->
  command =
    $pull: {}

  command.$pull["#{set}#{personOrGroupName}s"] =
    _id: personOrGroupId

  command

setRole = (documentName, documentId, personOrGroupName, personOrGroupId, role) ->
  person = Meteor.person()
  throw new Meteor.Error 401, "User not signed in." unless person

  # TODO: Optimize, not all fields are necessary
  document = accessDocuments[documentName].documents.findOne documentId
  throw new Meteor.Error 400, "Invalid document." unless document?.hasReadAccess person

  wasAdmin = (_.where document["admin#{personOrGroupName}s"], {_id: personOrGroupId}).length > 0
  wasMaintainer = (_.where document["maintainer#{personOrGroupName}s"], {_id: personOrGroupId}).length > 0
  hadReadAccess = (_.where document["read#{personOrGroupName}s"], {_id: personOrGroupId}).length > 0

  changesCount = 0

  # For private documents, grant read access together with admin/maintainer privileges.
  if document.access is ACCESS.PRIVATE and role >= ROLES.READ_ACCESS
    changesCount += accessDocuments[documentName].documents.update accessDocuments[documentName].requireAdminAccessSelector(person,
    createNotInSetQuery(documentId, 'read', personOrGroupName, personOrGroupId)),
    createAddToSetCommand('read', personOrGroupName, personOrGroupId)

  if role is ROLES.MAINTAINER
    changesCount += accessDocuments[documentName].documents.update accessDocuments[documentName].requireAdminAccessSelector(person,
    createNotInSetQuery(documentId, 'maintainer', personOrGroupName, personOrGroupId)),
    createAddToSetCommand('maintainer', personOrGroupName, personOrGroupId)

  if role is ROLES.ADMIN
    changesCount += accessDocuments[documentName].documents.update accessDocuments[documentName].requireAdminAccessSelector(person,
    createNotInSetQuery(documentId, 'admin', personOrGroupName, personOrGroupId)),
    createAddToSetCommand('admin', personOrGroupName, personOrGroupId)

  # Only clear read access for private documents when specifically clearing all rights
  if document.access is ACCESS.PRIVATE and hadReadAccess and role < ROLES.READ_ACCESS
    changesCount += accessDocuments[documentName].documents.update accessDocuments[documentName].requireAdminAccessSelector(person,
    createInSetQuery(documentId, 'read', personOrGroupName, personOrGroupId)),
    createRemoveFromSetCommand('read', personOrGroupName, personOrGroupId)

  if wasMaintainer and role isnt ROLES.MAINTAINER
    changesCount += accessDocuments[documentName].documents.update accessDocuments[documentName].requireAdminAccessSelector(person,
    createInSetQuery(documentId, 'maintainer', personOrGroupName, personOrGroupId)),
    createRemoveFromSetCommand('maintainer', personOrGroupName, personOrGroupId)

  if wasAdmin and role isnt ROLES.ADMIN
    changesCount += accessDocuments[documentName].documents.update accessDocuments[documentName].requireAdminAccessSelector(person,
    createInSetQuery(documentId, 'admin', personOrGroupName, personOrGroupId)),
    createRemoveFromSetCommand('admin', personOrGroupName, personOrGroupId)

  changesCount

# TODO: Use this code on the client side as well
Meteor.methods
  'set-role-for-person': (documentName, documentId, personId, role) ->
    check documentName, RegisteredForAccess
    check documentId, DocumentId
    check personId, DocumentId
    check role, Match.Where (role) ->
      check role, Match.OneOf null, Match.Integer
      return null <= role <= ROLES.ADMIN

    person = Person.documents.findOne
      _id: personId
    # No need for hasReadAccess because persons are public
    throw new Meteor.Error 400, "Invalid person." unless person

    setRole documentName, documentId, 'Person', personId, role

  'set-role-for-group': (documentName, documentId, groupId, role) ->
    check documentName, RegisteredForAccess
    check documentId, DocumentId
    check groupId, DocumentId
    check role, Match.Where (role) ->
      check role, Match.OneOf null, Match.Integer
      return null <= role <= ROLES.ADMIN

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    group = Group.documents.findOne
      _id: groupId
    throw new Meteor.Error 400, "Invalid group." unless group?.hasReadAccess person

    setRole documentName, documentId, 'Group', groupId, role

  'set-access': (documentName, documentId, access) ->
    check documentName, RegisteredForAccess
    check documentId, DocumentId
    check access, MatchAccess accessDocuments[documentName].ACCESS

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    # TODO: Optimize, not all fields are necessary
    document = accessDocuments[documentName].documents.findOne documentId
    throw new Meteor.Error 400, "Invalid document." unless document?.hasReadAccess person

    if access is ACCESS.PRIVATE
      accessDocuments[documentName].documents.update accessDocuments[documentName].requireAdminAccessSelector(person,
        _id: documentId
        access:
          $ne: access
      ),
        $set:
          access: access

    else
      accessDocuments[documentName].documents.update accessDocuments[documentName].requireAdminAccessSelector(person,
        _id: documentId
        access:
          $ne: access
      ),
        $set:
          access: access

Meteor.publish 'search-persons-groups', (query, except) ->
  except ?= []

  check query, NonEmptyString
  check except, [DocumentId]

  keywords = (keyword.replace /[-\\^$*+?.()|[\]{}]/g, '\\$&' for keyword in query.split /\s+/)

  findPersonQuery =
    $and: []
    _id:
      $nin: except
  findGroupQuery =
    $and: []
    _id:
      $nin: except

  # TODO: Use some smarter searching with provided query, probably using some real full-text search instead of regex
  for keyword in keywords when keyword
    regex = new RegExp keyword, 'i'
    findPersonQuery.$and.push
      $or: [
        _id: keyword
      ,
        'user.username': regex
      ,
        'user.emails.0.address': regex
      ,
        givenName: regex
      ,
        familyName: regex
      ]
    findGroupQuery.$and.push
      $or: [
        _id: keyword
      ,
        name: regex
      ]

  return unless findPersonQuery.$and.length + findGroupQuery.$and.length

  @related (person) ->
    restrictedFindGroupQuery = Group.requireReadAccessSelector person, findGroupQuery

    searchPublish @, 'search-persons-groups', query,
      # No need for requireReadAccessSelector because persons are public
      cursor: Person.documents.find findPersonQuery,
        limit: 5
        # TODO: Optimize fields, we do not need all
        fields: Person.PUBLISH_FIELDS().fields
    ,
      cursor: Group.documents.find restrictedFindGroupQuery,
        limit: 5
        # TODO: Optimize fields, we do not need all
        fields: Group.PUBLISH_FIELDS().fields
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: Publication.readAccessPersonFields()
