accessDocuments = {}

# Registers documents for which we want to support generic grant and revoke methods
@registerForAccess = (document) ->
  assert document.prototype instanceof ReadAccessDocument

  accessDocuments[document.Meta._name] = document

RegisteredForAccess = Match.Where (documentName) ->
  validateArgument documentName, String, 'documentName'
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

# When access is private, maintainers and admins should also be added to read access list
# so that if access is changed to public and then their maintainer or admin permission is
# revoked, they still retain read access if document is after all that switched back to
# private access. This logic is matched in BasicAccessDocument._applyDefaultAccess method.
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
  'set-role-for-person': methodWrap (documentName, documentId, personId, role) ->
    validateArgument documentName, RegisteredForAccess, 'documentName'
    validateArgument documentId, DocumentId, 'documentId'
    validateArgument personId, DocumentId, 'personId'
    validateArgument role, Match.Where (role) ->
      validateArgument role, Match.OneOf null, Match.Integer
      return role is null or 0 <= role <= ROLES.ADMIN
    , 'role'

    currentPerson = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless currentPerson

    !!setRole currentPerson, documentName, documentId, 'Person', personId, role

  'set-role-for-group': methodWrap (documentName, documentId, groupId, role) ->
    validateArgument documentName, RegisteredForAccess, 'documentName'
    validateArgument documentId, DocumentId, 'documentId'
    validateArgument groupId, DocumentId, 'groupId'
    validateArgument role, Match.Where (role) ->
      validateArgument role, Match.OneOf null, Match.Integer
      return role is null or 0 <= role <= ROLES.ADMIN
    , 'role'

    currentPerson = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless currentPerson

    !!setRole currentPerson, documentName, documentId, 'Group', groupId, role

  'set-access': methodWrap (documentName, documentId, access) ->
    validateArgument documentName, RegisteredForAccess, 'documentName'
    validateArgument documentId, DocumentId, 'documentId'
    validateArgument access, MatchAccess(accessDocuments[documentName].ACCESS), 'access'

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
