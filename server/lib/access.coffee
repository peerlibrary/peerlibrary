@requireReadAccess = (person, selector) ->
  return selector if person?.isAdmin

  # We use $or inside of $and to not override any existing $or
  selector.$and = [] unless selector.$and
  selector.$and.push
    $or: [
      access: ACCESS.PUBLIC
    ,
      access: ACCESS.PRIVATE
      'readUsers._id': person?._id
    ,
      access: ACCESS.PRIVATE
      'readGroups._id':
        $in: _.pluck person?.inGroups, '_id'
    ]
  selector

accessDocuments = {}

@registerForGranting = (document) ->
  accessDocuments[document.Meta._name] = document

RegisteredForGranting = Match.Where (documentName) ->
  check documentName, String
  documentName of accessDocuments

# TODO: Use this code on the client side as well for latency compensation, see https://github.com/meteor/meteor/issues/1921
Meteor.methods
  'grant-read-access-to-person': (documentName, documentId, personId) ->
    check documentName, RegisteredForGranting
    check documentId, String
    check personId, String

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
      'readUsers._id':
        $ne: personId
    ,
      $set:
        updatedAt: moment.utc().toDate()
      $addToSet:
        readUsers:
          _id: personId

  'grant-read-access-to-group': (documentName, documentId, groupId) ->
    check documentName, RegisteredForGranting
    check documentId, String
    check groupId, String

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
