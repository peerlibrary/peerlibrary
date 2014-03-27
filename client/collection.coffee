Deps.autorun ->
    if Session.get 'currentCollectionId'
      Meteor.subscribe 'collections-by-id', Session.get 'currentCollectionId'

Deps.autorun ->
  collection = Collection.documents.findOne Session.get('currentCollectionId'),
    fields:
      _id: 1
      slug: 1

  return unless collection

  # currentCollectionSlug is null if slug is not present in location, so we use
  # null when collection.slug is empty string to prevent infinite looping
  return if Session.equals 'currentCollectionSlug', (collection.slug or null)

  Meteor.Router.toNew Meteor.Router.collectionPath collection._id, collection.slug