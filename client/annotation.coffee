# A special client-only documenet which mirrors Annotation document, but allows adding
# temporary client-only annotations. We use this to be able to add temporary annotations
# for a current user which are not stored on the server until user inserts some real data.
# Then we upgrade a client-only annotation to a real annotation. You should always use
# LocalAnnotations for everything on the client side and leave to syncing code to do the rest.
class @LocalAnnotation extends Annotation
  @Meta
    name: 'LocalAnnotation'
    collection: null

Meteor.startup ->
  syncing = false

  wrapSyncing = (f) ->
    return if syncing

    try
      syncing = true
      return f()
    finally
      syncing = false

  Annotation.documents.find({}).observeChanges
    added: (id, fields) -> wrapSyncing ->
      LocalAnnotation.documents.insert _.extend {}, fields,
        _id: id

    changed: (id, fields) -> wrapSyncing ->
      LocalAnnotation.documents.update id,
        $set: fields

    removed: (id) -> wrapSyncing ->
      LocalAnnotation.documents.remove id

  localIds = {}

  LocalAnnotation.documents.find({}).observeChanges
    added: (id, fields) -> wrapSyncing ->
      if fields.local
        localIds[id] = true
      else
        delete fields.local
        Annotation.documents.insert _.extend {}, fields,
          _id: id

    changed: (id, fields) -> wrapSyncing ->
      if localIds[id]
        if 'local' of fields and not fields.local
          delete localIds[id]
          delete fields.local
          annotation = LocalAnnotation.documents.findOne id,
            transform: null
          Annotation.documents.insert _.extend annotation, fields
      else
        if fields.local
          localIds[id] = true
          Annotation.documents.remove id
        else
          Annotation.documents.update id,
            $set: fields

    removed: (id) -> wrapSyncing ->
      if localIds[id]
        delete localIds[id]
      else
        Annotation.documents.remove id

# Create an annotation document for current publication and current person
@createAnnotationDocument = ->
  # We prepopulate automatically generated fields as well because we
  # want them to be displayed even before they are saved to the server
  # TODO: We could add to PeerDB to generate fields on the client side as well?

  timestamp = moment.utc().toDate()

  created: timestamp
  updated: timestamp
  author: _.pick Meteor.person(), '_id', 'slug', 'givenName', 'familyName'
  publication:
    _id: Session.get 'currentPublicationId'
  highlights: []

# If we have the annotation and the publication available on the client,
# we can create full path directly, otherwise we have to use annotationIdPath
Handlebars.registerHelper 'annotationPathFromId', (annotatonId, options) ->
  annotation = LocalAnnotation.documents.findOne annotatonId

  return Meteor.Router.annotationIdPath annotatonId unless annotation

  publication = Publication.documents.findOne annotation.publication._id

  return Meteor.Router.annotationIdPath annotatonId unless publication

  Meteor.Router.annotationPath publication._id, publication.slug, annotatonId
