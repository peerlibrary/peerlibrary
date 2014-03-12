# A special client-only collection which mirrors Annotations collection, but allows adding
# temporary client-only annotations. We use this to be able to add temporary annotations
# for a current user which are not stored on the server until user inserts some real data.
# Then we upgrade a client-only annotation to a real annotation. You should always use
# LocalAnnotations for everything on the client side and leave to syncing code to do the rest.
@LocalAnnotations = new Meteor.Collection null, transform: (doc) => new @Annotation doc

Meteor.startup ->
  syncing = false

  wrapSyncing = (f) ->
    return if syncing

    try
      syncing = true
      return f()
    finally
      syncing = false

  Annotations.find({}).observeChanges
    added: (id, fields) -> wrapSyncing ->
      LocalAnnotations.insert _.extend {}, fields,
        _id: id

    changed: (id, fields) -> wrapSyncing ->
      LocalAnnotations.update id,
        $set: fields

    removed: (id) -> wrapSyncing ->
      LocalAnnotations.remove id

  localIds = {}

  LocalAnnotations.find({}).observeChanges
    added: (id, fields) -> wrapSyncing ->
      if fields.local
        localIds[id] = true
      else
        delete fields.local
        Annotations.insert _.extend {}, fields,
          _id: id

    changed: (id, fields) -> wrapSyncing ->
      if localIds[id]
        if 'local' of fields and not fields.local
          delete localIds[id]
          delete fields.local
          annotation = LocalAnnotations.findOne id,
            transform: null
          Annotations.insert _.extend annotation, fields
      else
        if fields.local
          localIds[id] = true
          Annotations.remove id
        else
          Annotations.update id,
            $set: fields

    removed: (id) -> wrapSyncing ->
      if localIds[id]
        delete localIds[id]
      else
        Annotations.remove id

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
  references:
    highlights: []
    annotations: []
    publications: []
    persons: []
    tags: []
  tags: []

# If we have the annotation and the publication available on the client,
# we can create full path directly, otherwise we have to use annotationIdPath
Handlebars.registerHelper 'annotationPathFromId', (annotatonId, options) ->
  annotation = Annotations.findOne annotatonId

  return Meteor.Router.annotationIdPath annotatonId unless annotation

  publication = Publications.findOne annotation.publication._id

  return Meteor.Router.annotationIdPath annotatonId unless publication

  Meteor.Router.annotationPath publication._id, publication.slug, annotatonId
