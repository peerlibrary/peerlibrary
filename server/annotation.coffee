class @Annotation extends Annotation
  @Meta
    name: 'Annotation'
    replaceParent: true

  # A set of fields which are public and can be published to the client
  @PUBLIC_FIELDS: ->
    fields: {} # All

Annotation.Meta.collection.allow
  insert: (userId, doc) ->
    # TODO: Check whether inserted document conforms to schema
    # TODO: Check that author really has access to the annotation

    return false unless userId

    personId = Meteor.personId userId

    # Only allow insertion if declared author is current user
    personId and doc.author._id is personId

  update: (userId, doc) ->
    return false unless userId

    personId = Meteor.personId userId

    # Only allow update if declared author is current user
    personId and doc.author._id is personId

  remove: (userId, doc) ->
    return false unless userId

    personId = Meteor.personId userId

    # Only allow removal if author is current user
    personId and doc.author._id is personId

# Misuse insert validation to add additional fields on the server before insertion
Annotation.Meta.collection.deny
  # We have to disable transformation so that we have
  # access to the document object which will be inserted
  transform: null

  insert: (userId, doc) ->
    doc.createdAt = moment.utc().toDate()
    doc.updatedAt = doc.createdAt
    doc.highlights = [] if not doc.highlights

    # We return false as we are not
    # checking anything, just adding fields
    false

  update: (userId, doc) ->
    doc.updatedAt = moment.utc().toDate()

    # We return false as we are not
    # checking anything, just updating fields
    false

# TODO: Deduplicate, almost same code is in publication.coffee (in general access control should be something consistent), it is similar also to member adding to a group code
Meteor.methods
  # TODO: Move this code to the client side so that we do not have to duplicate document checks from Annotation.Meta.collection.allow and modifications from Annotation.Meta.collection.deny, see https://github.com/meteor/meteor/issues/1921
  'annotation-grant-read-to-user': (annotationId, userId) ->
    check annotationId, String
    check userId, String

    throw new Meteor.Error 401, "User not signed in." unless Meteor.personId()

    # We do not check here if annotation exists or if user has already read permission because we have query below with these conditions

    # TODO: Check that userId has an user associated with it? Or should we allow adding persons even if they are not users? So that you can grant permissions to authors, without having for all of them to be registered?

    # TODO: Should be allowed also if user is admin
    # TODO: Should check if userId is a valid one?

    Annotation.documents.update
      _id: annotationId
      $and: [
        $or: [
          'readUsers._id': Meteor.personId()
        ,
          'readGroups._id':
            $in: _.pluck Meteor.person().inGroups, '_id'
        ]
      ,
        'readUsers._id':
          $ne: userId
      ]
    ,
      $set:
        updatedAt: moment.utc().toDate()
      $addToSet:
        readUsers:
          _id: userId

  # TODO: Move this code to the client side so that we do not have to duplicate document checks from Annotation.Meta.collection.allow and modifications from Annotation.Meta.collection.deny, see https://github.com/meteor/meteor/issues/1921
  'annotation-grant-read-to-group': (annotationId, groupId) ->
    check annotationId, String
    check groupId, String

    throw new Meteor.Error 401, "User not signed in." unless Meteor.personId()

    # We do not check here if annotation exists or if group has already read permission because we have query below with these conditions

    # TODO: Should be allowed also if user is admin
    # TODO: Should check if groupId is a valid one?

    Annotation.documents.update
      _id: annotationId
      $and: [
        $or: [
          'readUsers._id': Meteor.personId()
        ,
          'readGroups._id':
            $in: _.pluck Meteor.person().inGroups, '_id'
        ]
      ,
        'readGroups._id':
          $ne: groupId
      ]
    ,
      $set:
        updatedAt: moment.utc().toDate()
      $addToSet:
        readGroups:
          _id: groupId

# TODO: Should we use try/except around the code so that if there is any exception we stop handlers?
# TODO: Deduplicate code: it is similar to two functions in publication.coffee
publishUsingPermissions = (publish, selector, options) ->
  # There are moments when two observes are observing mostly similar list
  # of annotations ids so it could happen that one is changing or removing
  # annotation just while the other one is adding, so we are making sure
  # using currentAnnotations variable that we have a consistent view of the
  # annotations we published
  currentAnnotations = {}
  handleAnnotations = null

  publishAnnotations = (newIsAdmin, newGroups) =>
    newGroups ||= []

    initializing = true
    initializedAnnotations = []

    oldHandleAnnotations = handleAnnotations
    handleAnnotations = Annotation.documents.find(selector(newIsAdmin, newGroups), options).observeChanges
      added: (id, fields) =>
        initializedAnnotations.push id if initializing

        return if currentAnnotations[id]
        currentAnnotations[id] = true

        publish.added 'Annotations', id, fields

      changed: (id, fields) =>
        return if not currentAnnotations[id]

        publish.changed 'Annotations', id, fields

      removed: (id) =>
        return if not currentAnnotations[id]
        delete currentAnnotations[id]

        publish.removed 'Annotations', id

    initializing = false

    # We stop the handle after we established the new handle,
    # so that any possible changes hapenning in the meantime
    # were still processed by the old handle
    oldHandleAnnotations.stop() if oldHandleAnnotations

    # And then we remove those which are not published anymore
    for id in _.difference _.keys(currentAnnotations), initializedAnnotations
      delete currentAnnotations[id]
      publish.removed 'Annotations', id

  currentPersonId = null # Just for asserts

  if publish.personId
    handlePersons = Person.documents.find(
      _id: publish.personId
    ,
      fields:
        # _id field is implicitly added
        isAdmin: 1
        inGroups: 1
      transform: null # We are only interested in data
    ).observe
      added: (person) =>
        # There should be only one person with the id at every given moment
        assert.equal currentPersonId, null

        currentPersonId = person._id
        publishAnnotations person.isAdmin, _.pluck(person.inGroups, '_id')

      changed: (newPerson, oldPerson) =>
        # Person should already be added
        assert.equal currentPersonId, newPerson._id

        publishAnnotations newPerson.isAdmin, _.pluck(newPerson.inGroups, '_id')

      removed: (oldPerson) =>
        # We cannot remove the person if we never added the person before
        assert.equal currentPersonId, oldPerson._id

        currentPersonId = null
        publishAnnotations false, []

  # If we get to here and currentPersonId was not set when initializing,
  # we call publishAnnotations with empty list so that possibly something
  # is published. If later on person is added, publishAnnotations will be
  # simply called again.
  publishAnnotations false, [] unless currentPersonId

  publish.ready()

  publish.onStop =>
    handlePersons.stop() if handlePersons
    handleAnnotations.stop() if handleAnnotations

Meteor.publish 'annotations-by-id', (id) ->
  check id, String

  return unless id

  publishUsingPermissions @, (isAdmin, groups) =>
    if isAdmin
      _id: id
    else
      _id: id
      $or: [
        access: Annotation.ACCESS.PUBLIC
      ,
        access: Annotation.ACCESS.PRIVATE
        'readUsers._id': @personId
      ,
        access: Annotation.ACCESS.PRIVATE
        'readGroups._id':
          $in: groups
      ]
  ,
    Annotation.PUBLIC_FIELDS()

Meteor.publish 'annotations-by-publication', (publicationId) ->
  check publicationId, String

  return unless publicationId

  publishUsingPermissions @, (isAdmin, groups) =>
    if isAdmin
      'publication._id': publicationId
    else
      'publication._id': publicationId
      $or: [
        access: Annotation.ACCESS.PUBLIC
      ,
        access: Annotation.ACCESS.PRIVATE
        'readUsers._id': @personId
      ,
        access: Annotation.ACCESS.PRIVATE
        'readGroups._id':
          $in: groups
      ]
  ,
    Annotation.PUBLIC_FIELDS()
