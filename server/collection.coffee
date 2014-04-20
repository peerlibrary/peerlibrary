SLUG_MAX_LENGTH = 80

class @Collection extends Collection
  @Meta
    name: 'Collection'
    replaceParent: true
    fields: (fields) =>
      fields.slug.generator = (fields) ->
        if fields.name
          [fields._id, URLify2 fields.name, SLUG_MAX_LENGTH]
        else
          [fields._id, '']

  # A set of fields which are public and can be published to the client
  @PUBLIC_FIELDS: ->
    fields: {} # All

# TODO: Use this code on the client side as well
Meteor.methods
  'create-collection': (name) ->
    check name, NonEmptyString

    throw new Meteor.Error 401, "User not signed in." unless Meteor.personId()

    createdAt = moment.utc().toDate()
    collection =
      createdAt: createdAt
      updatedAt: createdAt
      name: name
      authorPerson:
        _id: Meteor.personId()
      publications: []

    collection = Collection.applyDefaultAccess Meteor.personId(), collection

    Collection.documents.insert collection

  'remove-collection': (collectionId) ->
    check collectionId, DocumentId

    throw new Meteor.Error 401, "User not signed in." unless Meteor.personId()

    # TODO: Check permissions (or simply limit query to them)

    Collection.documents.remove collectionId

  'add-to-library': (publicationId, collectionId) ->
    check publicationId, DocumentId
    check collectionId, Match.Optional DocumentId

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    publication = Publication.documents.findOne publicationId
    throw new Meteor.Error 400, "Invalid publication." unless publication?.hasReadAccess person

    # Add to user's library
    result = Person.documents.update
      '_id': person._id
      'library._id':
        $ne: publicationId
    ,
      $set:
        updatedAt: moment.utc().toDate()
      $addToSet:
        library:
          _id: publicationId

    # Optionally add the publication to a collection, if it was specified
    return result unless collectionId

    collection = Collection.documents.findOne
      _id: collectionId

    throw new Meteor.Error 400, "Invalid collection." unless collection

    Collection.documents.update
      _id: collectionId
      'authorPerson._id': person._id
      'publications._id':
        $ne: publicationId
    ,
      $set:
        updatedAt: moment.utc().toDate()
      $addToSet:
        publications:
          _id: publicationId

  'remove-from-library': (publicationId, collectionId) ->
    check publicationId, DocumentId
    check collectionId, Match.Optional DocumentId

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    publication = Publication.documents.findOne publicationId
    throw new Meteor.Error 400, "Invalid publication." unless publication?.hasReadAccess person

    # When we're removing from library we also want to remove the publication from all user's collections.
    # This query will match all user's collections that include this publication.
    collectionsQuery =
      'authorPerson._id': person._id
      'publications._id': publicationId

    # If collectionId is specified we modify the query to only remove from that collection
    if collectionId
      collection = Collection.documents.findOne
        _id: collectionId

      throw new Meteor.Error 400, "Invalid collection." unless collection

      collectionsQuery['_id'] = collectionId

    # Remove from collection
    result = Collection.documents.update collectionsQuery,
      $set:
        updatedAt: moment.utc().toDate()
      $pull:
        publications:
          _id: publicationId
    ,
      multi: not collectionId?

    # Only remove from library if collection was not specified
    return result if collectionId

    Person.documents.update
      '_id': person._id
      'library._id': publicationId
    ,
      $set:
        updatedAt: moment.utc().toDate()
      $pull:
        library:
          _id: publicationId

  'reorder-collection': (collectionId, publicationIds) ->
    check collectionId, DocumentId
    check publicationIds, [DocumentId]

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    collection = Collection.documents.findOne collectionId

    throw new Meteor.Error 400, "Invalid collection." unless collection and collection.authorPerson?._id is person._id

    oldOrderIds = _.pluck collection.publications, '_id'

    throw new Meteor.Error 400, "Invalid collection." if _.difference(oldOrderIds, publicationIds).length

    publications = (_id: publicationId for publicationId in publicationIds)

    Collection.documents.update
      _id: collectionId
      'publications._id':
        $all: oldOrderIds
      publications:
        $size: oldOrderIds.length
    ,
      $set:
        publications: publications

Meteor.publish 'collection-by-id', (id) ->
  check id, DocumentId

  Collection.documents.find
    _id: id
  ,
    Collection.PUBLIC_FIELDS()

Meteor.publish 'my-collections', ->
  Collection.documents.find
    'authorPerson._id': @personId
  ,
    Collection.PUBLIC_FIELDS()

Meteor.publish 'collection-publications', (collectionId) ->
  check collectionId, DocumentId

  @related (person, collection) ->
    Publication.documents.find Publication.requireReadAccessSelector(person,
      _id:
        $in: _.pluck collection.publications, '_id'
    ), Publication.PUBLIC_FIELDS()
  ,
    Person.documents.find
      _id: @personId
    ,
      fields:
        # _id field is implicitly added
        isAdmin: 1
        inGroups: 1
        library: 1
  ,
    Collection.documents.find
      _id: collectionId
    ,
      fields:
        publications: 1
