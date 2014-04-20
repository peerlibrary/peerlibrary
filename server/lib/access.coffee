accessDocuments = {}

# Registers documents for which we want to support generic grant and revoke methods
@registerForAccess = (document) ->
  assert document.prototype instanceof AccessDocument

  accessDocuments[document.Meta._name] = document

RegisteredForAccess = Match.Where (documentName) ->
  check documentName, String
  accessDocuments.hasOwnProperty documentName

MatchAccess = (access) ->
  values = _.values access
  Match.Where (a) ->
    check a, Number
    a in values

# TODO: Use this code on the client side as well for latency compensation, see https://github.com/meteor/meteor/issues/1921
Meteor.methods
  'grant-read-access-to-person': (documentName, documentId, personId) ->
    check documentName, RegisteredForAccess
    check documentId, DocumentId
    check personId, DocumentId

    throw new Meteor.Error 401, "User not signed in." unless Meteor.personId()

    # TODO: Optimize, not all fields are necessary
    document = accessDocuments[documentName].documents.findOne documentId

    throw new Meteor.Error 403, "Permission denied." unless document?.hasReadAccess Meteor.person()

    return 0 unless document.access is ACCESS.PRIVATE

    # TODO: Optimize check for existence
    person = Person.documents.findOne
      _id: personId

    return 0 unless person

    accessDocuments[documentName].documents.update
      _id: documentId
      'readPersons._id':
        $ne: personId
    ,
      $set:
        updatedAt: moment.utc().toDate()
      $addToSet:
        readPersons:
          _id: personId

  'grant-read-access-to-group': (documentName, documentId, groupId) ->
    check documentName, RegisteredForAccess
    check documentId, DocumentId
    check groupId, DocumentId

    throw new Meteor.Error 401, "User not signed in." unless Meteor.personId()

    # TODO: Optimize, not all fields are necessary
    document = accessDocuments[documentName].documents.findOne documentId

    throw new Meteor.Error 403, "Permission denied." unless document?.hasReadAccess Meteor.person()

    return 0 unless document.access is ACCESS.PRIVATE

    # TODO: Optimize check for existence
    group = Group.documents.findOne
      _id: groupId

    # TODO: If we will allow private groups, then we have to call hasReadAccess on the group as well

    return 0 unless group

    accessDocuments[documentName].documents.update
      _id: documentId
      'readGroups._id':
        $ne: groupId
    ,
      $set:
        updatedAt: moment.utc().toDate()
      $addToSet:
        readGroups:
          _id: groupId

  'revoke-read-access-for-person': (documentName, documentId, personId) ->
    check documentName, RegisteredForAccess
    check documentId, DocumentId
    check personId, DocumentId

    throw new Meteor.Error 401, "User not signed in." unless Meteor.personId()

    # TODO: Optimize, not all fields are necessary
    document = accessDocuments[documentName].documents.findOne documentId

    throw new Meteor.Error 403, "Permission denied." unless document?.hasReadAccess Meteor.person()

    return 0 unless document.access is ACCESS.PRIVATE

    accessDocuments[documentName].documents.update
      _id: documentId
      'readPersons._id': personId
    ,
      $set:
        updatedAt: moment.utc().toDate()
      $pull:
        readPersons:
          _id: personId

  'revoke-read-access-for-group': (documentName, documentId, groupId) ->
    check documentName, RegisteredForAccess
    check documentId, DocumentId
    check groupId, DocumentId

    throw new Meteor.Error 401, "User not signed in." unless Meteor.personId()

    # TODO: Optimize, not all fields are necessary
    document = accessDocuments[documentName].documents.findOne documentId

    throw new Meteor.Error 403, "Permission denied." unless document?.hasReadAccess Meteor.person()

    return 0 unless document.access is ACCESS.PRIVATE

    # TODO: If we will allow private groups, then we have to call hasReadAccess on the group as well

    accessDocuments[documentName].documents.update
      _id: documentId
      'readGroups._id': groupId
    ,
      $set:
        updatedAt: moment.utc().toDate()
      $pull:
        readGroups:
          _id: groupId

  'set-access': (documentName, documentId, access) ->
    check documentName, RegisteredForAccess
    check documentId, DocumentId
    check access, MatchAccess accessDocuments[documentName].ACCESS

    throw new Meteor.Error 401, "User not signed in." unless Meteor.personId()

    # TODO: Optimize, not all fields are necessary
    document = accessDocuments[documentName].documents.findOne documentId

    throw new Meteor.Error 403, "Permission denied." unless document?.hasReadAccess Meteor.person()

    if access is ACCESS.PRIVATE
      accessDocuments[documentName].documents.update
        _id: documentId
        access:
          $ne: access
      ,
        $set: _.extend accessDocuments[documentName].defaultPrivateAccessSettings(Meteor.personId(), documentId),
          access: access

    else
      accessDocuments[documentName].documents.update
        _id: documentId
        access:
          $ne: access
      ,
        $set:
          access: access
          readPersons: []
          readGroups: []

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

  # TODO: If we will allow private groups, then we will have to filter here

  searchPublish @, 'search-persons-groups', query,
    cursor: Person.documents.find findPersonQuery,
      limit: 5
      fields: Person.PUBLIC_FIELDS().fields
  ,
    cursor: Group.documents.find findGroupQuery,
      limit: 5
      fields: Group.PUBLIC_FIELDS().fields
