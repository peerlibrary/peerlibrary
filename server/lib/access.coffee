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

# TODO: Use this code on the client side as well
Meteor.methods
  'grant-read-access-to-person': (documentName, documentId, personId) ->
    check documentName, RegisteredForAccess
    check documentId, DocumentId
    check personId, DocumentId

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    # TODO: Optimize, not all fields are necessary
    document = accessDocuments[documentName].documents.findOne documentId
    throw new Meteor.Error 400, "Invalid document." unless document?.hasReadAccess person

    person2 = Person.documents.findOne
      _id: personId
    # No need for hasReadAccess because persons are public
    throw new Meteor.Error 400, "Invalid person." unless person2

    return 0 unless document.access is ACCESS.PRIVATE

    accessDocuments[documentName].documents.update accessDocuments[documentName].requireAdminAccessSelector(person,
      _id: documentId
      'readPersons._id':
        $ne: personId
    ),
      $set:
        updatedAt: moment.utc().toDate()
      $addToSet:
        readPersons:
          _id: personId

  'grant-read-access-to-group': (documentName, documentId, groupId) ->
    check documentName, RegisteredForAccess
    check documentId, DocumentId
    check groupId, DocumentId

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    # TODO: Optimize, not all fields are necessary
    document = accessDocuments[documentName].documents.findOne documentId
    throw new Meteor.Error 400, "Invalid document." unless document?.hasReadAccess person

    group = Group.documents.findOne
      _id: groupId
    throw new Meteor.Error 400, "Invalid group." unless group?.hasReadAccess person

    return 0 unless document.access is ACCESS.PRIVATE

    accessDocuments[documentName].documents.update accessDocuments[documentName].requireAdminAccessSelector(person,
      _id: documentId
      'readGroups._id':
        $ne: groupId
    ),
      $set:
        updatedAt: moment.utc().toDate()
      $addToSet:
        readGroups:
          _id: groupId

  'revoke-read-access-for-person': (documentName, documentId, personId) ->
    check documentName, RegisteredForAccess
    check documentId, DocumentId
    check personId, DocumentId

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    # TODO: Optimize, not all fields are necessary
    document = accessDocuments[documentName].documents.findOne documentId
    throw new Meteor.Error 400, "Invalid document." unless document?.hasReadAccess person

    person2 = Person.documents.findOne
      _id: personId
    # No need for hasReadAccess because persons are public
    throw new Meteor.Error 400, "Invalid person." unless person2

    return 0 unless document.access is ACCESS.PRIVATE

    accessDocuments[documentName].documents.update accessDocuments[documentName].requireAdminAccessSelector(person,
      _id: documentId
      'readPersons._id': personId
    ),
      $set:
        updatedAt: moment.utc().toDate()
      $pull:
        readPersons:
          _id: personId

  'revoke-read-access-for-group': (documentName, documentId, groupId) ->
    check documentName, RegisteredForAccess
    check documentId, DocumentId
    check groupId, DocumentId

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    # TODO: Optimize, not all fields are necessary
    document = accessDocuments[documentName].documents.findOne documentId
    throw new Meteor.Error 400, "Invalid document." unless document?.hasReadAccess person

    group = Group.documents.findOne
      _id: groupId
    throw new Meteor.Error 400, "Invalid group." unless group?.hasReadAccess person

    return 0 unless document.access is ACCESS.PRIVATE

    accessDocuments[documentName].documents.update accessDocuments[documentName].requireAdminAccessSelector(person,
      _id: documentId
      'readGroups._id': groupId
    ),
      $set:
        updatedAt: moment.utc().toDate()
      $pull:
        readGroups:
          _id: groupId

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
        $set: _.extend accessDocuments[documentName].defaultPrivateAccessSettings(person._id, documentId),
          access: access

    else
      accessDocuments[documentName].documents.update accessDocuments[documentName].requireAdminAccessSelector(person,
        _id: documentId
        access:
          $ne: access
      ),
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
