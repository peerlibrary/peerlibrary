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
  @PUBLISH_FIELDS: ->
    fields: {} # All

registerForAccess Collection

Meteor.methods
  'create-collection': (name) ->
    check name, NonEmptyString

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    createdAt = moment.utc().toDate()
    collection =
      createdAt: createdAt
      updatedAt: createdAt
      name: name
      authorPerson:
        _id: person._id
      publications: []

    collection = Collection.applyDefaultAccess person._id, collection

    Collection.documents.insert collection

  # TODO: Use this code on the client side as well
  'remove-collection': (collectionId) ->
    check collectionId, DocumentId

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    collection = Collection.documents.findOne Collection.requireReadAccessSelector(person,
      _id: collectionId
    )
    throw new Meteor.Error 400, "Invalid collection." unless collection

    Collection.documents.remove Collection.requireRemoveAccessSelector(person,
      _id: collection._id
    )

  # TODO: Use this code on the client side as well
  'add-to-library': (publicationId, collectionId) ->
    check publicationId, DocumentId
    check collectionId, Match.Optional DocumentId

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    publication = Publication.documents.findOne Publication.requireReadAccessSelector(person,
      _id: publicationId
    )
    throw new Meteor.Error 400, "Invalid publication." unless publication

    # Add to user's library
    result = Person.documents.update Person.requireMaintainerAccessSelector(person,
      _id: person._id
      'library._id':
        $ne: publication._id
    ),
      $addToSet:
        library:
          _id: publication._id

    # Optionally add the publication to a collection, if it was specified
    return result unless collectionId

    collection = Collection.documents.findOne Collection.requireReadAccessSelector(person,
      _id: collectionId
    )
    throw new Meteor.Error 400, "Invalid collection." unless collection

    Collection.documents.update Collection.requireMaintainerAccessSelector(person,
      _id: collection._id
      'publications._id':
        $ne: publication._id
    ),
      $addToSet:
        publications:
          _id: publication._id

  # TODO: Use this code on the client side as well
  'remove-from-library': (publicationId, collectionId) ->
    check publicationId, DocumentId
    check collectionId, Match.Optional DocumentId

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    publication = Publication.documents.findOne Publication.requireReadAccessSelector(person,
      _id: publicationId
    )
    throw new Meteor.Error 400, "Invalid publication." unless publication

    if collectionId
      collection = Collection.documents.findOne Collection.requireReadAccessSelector(person,
        _id: collectionId
      )
      throw new Meteor.Error 400, "Invalid collection." unless collection

      # If collectionId is specified we only remove from that collection
      collectionsQuery =
        _id: collection._id
        'publications._id': publication._id
    else
      # When we're removing from library we also want to remove the publication from all user's
      # collections. This query will match all user's collections that include this publication.
      collectionsQuery =
        'authorPerson._id': person._id
        'publications._id': publication._id

    # Remove from collection
    result = Collection.documents.update Collection.requireMaintainerAccessSelector(person,
      collectionsQuery
    ),
      $pull:
        publications:
          _id: publication._id
    ,
      multi: not collectionId?

    # Only remove from library if collection was not specified
    return result if collectionId

    Person.documents.update Person.requireMaintainerAccessSelector(person,
      '_id': person._id
      'library._id': publication._id
    ),
      $pull:
        library:
          _id: publication._id

  # TODO: Use this code on the client side as well
  'reorder-collection': (collectionId, publicationIds) ->
    check collectionId, DocumentId
    check publicationIds, [DocumentId]

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    collection = Collection.documents.findOne Collection.requireReadAccessSelector(person,
      _id: collectionId
    )
    throw new Meteor.Error 400, "Invalid collection." unless collection

    oldOrderIds = _.pluck collection.publications, '_id'

    throw new Meteor.Error 400, "Invalid collection." if _.difference(oldOrderIds, publicationIds).length

    publications = (_id: publicationId for publicationId in publicationIds)

    Collection.documents.update Collection.requireMaintainerAccessSelector(person,
      _id: collection._id
      'publications._id':
        $all: oldOrderIds
      publications:
        $size: oldOrderIds.length
    ),
      $set:
        publications: publications

  # TODO: Use this code on the client side as well
  'collection-set-name': (collectionId, name) ->
    check collectionId, DocumentId
    check name, NonEmptyString

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    collection = Collection.documents.findOne Collection.requireReadAccessSelector(person,
      _id: collectionId
    )
    throw new Meteor.Error 400, "Invalid collection." unless collection

    Collection.documents.update Group.requireMaintainerAccessSelector(person,
        _id: collection._id
      ),
      $set:
        name: name

Meteor.publish 'collection-by-id', (collectionId) ->
  check collectionId, DocumentId

  @related (person) ->
    Collection.documents.find Collection.requireReadAccessSelector(person,
      _id: collectionId
    ),
      Collection.PUBLISH_FIELDS()
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: _.extend Collection.readAccessPersonFields()

Meteor.publish 'my-collections', ->
  @related (person) ->
    return unless person?._id

    Collection.documents.find Collection.requireReadAccessSelector(person,
      'authorPerson._id': person._id
    ),
      Collection.PUBLISH_FIELDS()
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: _.extend Collection.readAccessPersonFields()

Meteor.publish 'publications-by-collection', (collectionId) ->
  check collectionId, DocumentId

  @related (person, collection) ->
    return unless collection?.hasReadAccess person
    return unless collection?.publications

    Publication.documents.find Publication.requireReadAccessSelector(person,
      _id:
        $in: _.pluck collection.publications, '_id'
    ),
      Publication.PUBLISH_FIELDS()
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: Publication.readAccessPersonFields()
  ,
    Collection.documents.find
      _id: collectionId
    ,
      fields: _.extend Collection.readAccessSelfFields(),
        publications: 1
