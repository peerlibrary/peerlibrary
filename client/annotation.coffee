# A special client-only document which mirrors Annotation document. Anything
# added to it will not be stored to the server, but any changes to Annotation
# document will be refleced in this client-only document.
# We use this to be able to add temporary annotations for a current user which
# are not stored on the server until user inserts some real data. Then we upgrade
# a client-only annotation to a real annotation. You should always use
# LocalAnnotations when reading annotations on the client.
class @LocalAnnotation extends Annotation
  @Meta
    name: 'LocalAnnotation'
    collection: null

Meteor.startup ->
  Annotation.documents.find({}).observeChanges
    added: (id, fields) ->
      LocalAnnotation.documents.upsert id,
        $set: fields

    changed: (id, fields) ->
      LocalAnnotation.documents.update id,
        $set: fields

    removed: (id) ->
      LocalAnnotation.documents.remove id

# Create an annotation document for current publication and current person
@createAnnotationDocument = ->
  # We prepopulate automatically generated fields as well because we
  # want them to be displayed even before they are saved to the server
  # TODO: We could add to PeerDB to generate fields on the client side as well?

  timestamp = moment.utc().toDate()

  author = _.pick Meteor.person(), '_id', 'slug', 'givenName', 'familyName', 'gravatarHash'
  author.user = _.pick Meteor.person().user, 'username'

  createdAt: timestamp
  updatedAt: timestamp
  author: author
  publication:
    _id: Session.get 'currentPublicationId'
  references:
    highlights: []
    annotations: []
    publications: []
    persons: []
    tags: []
  tags: []
  body: ''

# If we have the annotation and the publication available on the client,
# we can create full path directly, otherwise we have to use annotationIdPath
Handlebars.registerHelper 'annotationPathFromId', (annotationId, options) ->
  annotation = LocalAnnotation.documents.findOne annotationId

  return Meteor.Router.annotationIdPath annotationId unless annotation

  publication = Publication.documents.findOne annotation.publication._id

  return Meteor.Router.annotationIdPath annotationId unless publication

  Meteor.Router.annotationPath publication._id, publication.slug, annotationId
