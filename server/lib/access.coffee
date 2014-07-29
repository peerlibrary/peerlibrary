accessDocuments = {}

# Registers documents for which we want to support generic grant and revoke methods
@registerForAccess = (document) ->
  assert document.prototype instanceof ReadAccessDocument

  accessDocuments[document.Meta._name] = document

RegisteredForAccess = Match.Where (documentName) ->
  check documentName, String
  accessDocuments.hasOwnProperty documentName

createNotInSetQuery = (documentId, set, personOrGroup, personOrGroupId) ->
  query =
    _id: documentId

  query["#{ set }#{ personOrGroup }s._id"] =
    $ne: personOrGroupId

  query

createAddToSetCommand = (set, personOrGroup, personOrGroupId) ->
  command =
    $addToSet: {}

  command.$addToSet["#{ set }#{ personOrGroup }s"] =
    _id: personOrGroupId

  command

createInSetQuery = (documentId, set, personOrGroup, personOrGroupId) ->
  query =
    _id: documentId

  query["#{ set }#{ personOrGroup }s._id"] = personOrGroupId

  query

createRemoveFromSetCommand = (set, personOrGroup, personOrGroupId) ->
  command =
    $pull: {}

  command.$pull["#{ set }#{ personOrGroup }s"] =
    _id: personOrGroupId

  command

setRole = (currentPerson, documentName, documentId, personOrGroup, personOrGroupId, role) ->
  assert currentPerson

  changesCount = 0

  # For private documents, grant read access together with admin/maintainer privileges
  if role isnt null and role >= ROLES.READ_ACCESS
    changesCount += accessDocuments[documentName].documents.update accessDocuments[documentName].requireAdminAccessSelector(currentPerson,
      _.extend createNotInSetQuery(documentId, 'read', personOrGroup, personOrGroupId),
        access: ACCESS.PRIVATE
    ), createAddToSetCommand 'read', personOrGroup, personOrGroupId

  if role is ROLES.MAINTAINER
    changesCount += accessDocuments[documentName].documents.update accessDocuments[documentName].requireAdminAccessSelector(currentPerson,
      createNotInSetQuery documentId, 'maintainer', personOrGroup, personOrGroupId
    ), createAddToSetCommand 'maintainer', personOrGroup, personOrGroupId

  if role is ROLES.ADMIN
    changesCount += accessDocuments[documentName].documents.update accessDocuments[documentName].requireAdminAccessSelector(currentPerson,
      createNotInSetQuery documentId, 'admin', personOrGroup, personOrGroupId
    ), createAddToSetCommand 'admin', personOrGroup, personOrGroupId

  # Only clear read access for private documents when specifically clearing all permissions
  if role is null
    changesCount += accessDocuments[documentName].documents.update accessDocuments[documentName].requireAdminAccessSelector(currentPerson,
      _.extend createInSetQuery(documentId, 'read', personOrGroup, personOrGroupId),
        access: ACCESS.PRIVATE
    ), createRemoveFromSetCommand 'read', personOrGroup, personOrGroupId

  if role isnt ROLES.MAINTAINER
    changesCount += accessDocuments[documentName].documents.update accessDocuments[documentName].requireAdminAccessSelector(currentPerson,
      createInSetQuery documentId, 'maintainer', personOrGroup, personOrGroupId
    ), createRemoveFromSetCommand 'maintainer', personOrGroup, personOrGroupId

  if role isnt ROLES.ADMIN
    changesCount += accessDocuments[documentName].documents.update accessDocuments[documentName].requireAdminAccessSelector(currentPerson,
      createInSetQuery documentId, 'admin', personOrGroup, personOrGroupId
    ), createRemoveFromSetCommand 'admin', personOrGroup, personOrGroupId

  changesCount

# TODO: Use this code on the client side as well
Meteor.methods
  'set-role-for-person': (documentName, documentId, personId, role) ->
    check documentName, RegisteredForAccess
    check documentId, DocumentId
    check personId, DocumentId
    check role, Match.Where (role) ->
      check role, Match.OneOf null, Match.Integer
      return role is null or 0 <= role <= ROLES.ADMIN

    currentPerson = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless currentPerson

    !!setRole currentPerson, documentName, documentId, 'Person', personId, role

  'set-role-for-group': (documentName, documentId, groupId, role) ->
    check documentName, RegisteredForAccess
    check documentId, DocumentId
    check groupId, DocumentId
    check role, Match.Where (role) ->
      check role, Match.OneOf null, Match.Integer
      return role is null or 0 <= role <= ROLES.ADMIN

    currentPerson = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless currentPerson

    !!setRole currentPerson, documentName, documentId, 'Group', groupId, role

  'set-access': (documentName, documentId, access) ->
    check documentName, RegisteredForAccess
    check documentId, DocumentId
    check access, MatchAccess accessDocuments[documentName].ACCESS

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    if access is ACCESS.PRIVATE
      !!accessDocuments[documentName].documents.update accessDocuments[documentName].requireAdminAccessSelector(person,
        _id: documentId
        access:
          $ne: access
      ),
        $set:
          access: access

    else
      !!accessDocuments[documentName].documents.update accessDocuments[documentName].requireAdminAccessSelector(person,
        _id: documentId
        access:
          $ne: access
      ),
        $set:
          access: access
