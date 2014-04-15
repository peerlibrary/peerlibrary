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

Collection.Meta.collection.allow
  insert: (userId, doc) ->
    # TODO: Check whether inserted document conforms to schema
    # TODO: Check that author really has access to the publication

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
Collection.Meta.collection.deny
# We have to disable transformation so that we have
# access to the document object which will be inserted
  transform: null

  insert: (userId, doc) ->
    doc.createdAt = moment.utc().toDate()
    doc.updatedAt = doc.createdAt
    doc.publications = [] if not doc.publications

    # We return false as we are not
    # checking anything, just adding fields
    false

  update: (userId, doc) ->
    doc.updatedAt = moment.utc().toDate()

    # We return false as we are not
    # checking anything, just updating fields
    false

Meteor.methods
  #TODO: Move this code to the client side so that we do not have to duplicate document checks from Collection.Meta.collection.allow and modifications from Collection.Meta.collection.deny, see https://github.com/meteor/meteor/issues/1921
  'add-to-collection': (collectionId, publicationId) ->
    check collectionId, String
    check publicationId, String

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    collection = Collection.documents.findOne
      _id: collectionId

    throw new Meteor.Error 400, "Invalid collection." unless collection

    publication = Publication.documents.findOne
      _id: publicationId

    throw new Meteor.Error 400, "Invalid publication." unless publication

    # Add to user's library if needed
    unless _.contains (_.pluck person.library, '_id'), publicationId
      Person.documents.update
        '_id': person._id
      ,
        $addToSet:
          library:
            _id: publicationId

    # Add to collection
    Collection.documents.update
      _id: collectionId
      $and: [
        'author._id': person._id
      ,
        'publications._id':
          $ne: publicationId
      ]
    ,
      $set:
        updatedAt: moment.utc().toDate()
      $addToSet:
        publications:
          _id: publicationId

  #TODO: Move this code to the client side so that we do not have to duplicate document checks from Collection.Meta.collection.allow and modifications from Collection.Meta.collection.deny, see https://github.com/meteor/meteor/issues/1921
  'remove-from-collection': (collectionId, publicationId) ->
    check collectionId, String
    check publicationId, String

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    collection = Collection.documents.findOne
      _id: collectionId

    throw new Meteor.Error 400, "Invalid collection." unless collection

    publication = Publication.documents.findOne
      _id: publicationId

    throw new Meteor.Error 400, "Invalid publication." unless publication

    # Remove from collection
    Collection.documents.update
      _id: collectionId
      $and: [
        'author._id': person._id
      ,
        'publications._id': publicationId
      ]
    ,
      $set:
        updatedAt: moment.utc().toDate()
      $pull:
        publications:
          _id: publicationId

  'reorder-collection': (collectionId, publicationIds) ->
    check collectionId, String
    check publicationIds, [String]

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    collection = Collection.documents.findOne collectionId

    throw new Meteor.Error 401, "Collection not found." unless collection

    throw new Meteor.Error 403, "User not collection's author." unless collection.author._id is person._id

    oldOrderIds = _.pluck collection.publications, '_id'

    throw new Meteor.Error 400, "Provided Ids don't match." if _.difference(oldOrderIds, publicationIds).length

    publications = (_id: publicationId for publicationId in publicationIds)

    Collection.documents.update
      _id: collectionId
    ,
      $set:
        publications: publications

Meteor.publish 'collection-by-id', (id) ->
  check id, String

  return unless id

  Collection.documents.find
    _id: id
  ,
    Collection.PUBLIC_FIELDS()

Meteor.publish 'my-collections', ->

  Collection.documents.find
    'author._id': @personId
  ,
    Collection.PUBLIC_FIELDS()

Meteor.publish 'collection-publications', (id) ->
  check id, String

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
      _id: id
    ,
      fields:
        publications: 1