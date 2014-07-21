# We count only once on the server and update a shared
# local collection to which clients then subscribe

Meteor.startup ->
  statisticsDataId = Random.id()
  initializingPublications = true
  initializingPersons = true
  initializingHighlights = true
  initializingAnnotations = true
  initializingGroups = true
  initializingCollections = true
  initializingBlogPosts = true
  countPublications = 0
  countPersons = 0
  countHighlights = 0
  countAnnotations = 0
  countGroups = 0
  countCollections = 0
  countBlogPosts = 0
  minPublicationDate = null
  maxPublicationDate = null

  Publication.documents.find({},
    fields:
      # _id field is implicitly added
      createdAt: 1
  ).observeChanges
    added: (id, fields) =>
      countPublications++

      createdAt = moment.utc fields.createdAt

      changed =
        countPublications: countPublications

      if not minPublicationDate or createdAt < minPublicationDate
        minPublicationDate = createdAt
        changed.minPublicationDate = minPublicationDate.toDate()

      if not maxPublicationDate or createdAt > maxPublicationDate
        maxPublicationDate = createdAt
        changed.maxPublicationDate = maxPublicationDate.toDate()

      Statistics.documents.update statisticsDataId, $set: changed if !initializingPublications

    changed: (id, fields) =>
      return unless fields.createdAt

      createdAt = moment.utc fields.createdAt

      changed = {}

      if createdAt < minPublicationDate
        minPublicationDate = createdAt
        changed.minPublicationDate = createdAt.toDate()

      if createdAt > maxPublicationDate
        maxPublicationDate = createdAt
        changed.maxPublicationDate = createdAt.toDate()

      Statistics.documents.update statisticsDataId, $set: changed if !initializingPublications and _.size changed

    removed: (id) =>
      countPublications--
      Statistics.documents.update statisticsDataId, $set: countPublications: countPublications if !initializingPublications

      # We ignore removed publications for minPublicationDate and maxPublicationDate.
      # This much simplifies the code and there is not really a big drawback because of this.

  Person.documents.find({},
    fields:
      _id: 1 # We want only id
  ).observeChanges
    added: (id) =>
      countPersons++
      Statistics.documents.update statisticsDataId, $set: countPersons: countPersons if !initializingPersons

    removed: (id) =>
      countPersons--
      Statistics.documents.update statisticsDataId, $set: countPersons: countPersons if !initializingPersons

  Highlight.documents.find({},
    fields:
      _id: 1 # We want only id
  ).observeChanges
    added: (id) =>
      countHighlights++
      Statistics.documents.update statisticsDataId, $set: countHighlights: countHighlights if !initializingHighlights

    removed: (id) =>
      countHighlights--
      Statistics.documents.update statisticsDataId, $set: countHighlights: countHighlights if !initializingHighlights

  Annotation.documents.find({},
    fields:
      _id: 1 # We want only id
  ).observeChanges
    added: (id) =>
      countAnnotations++
      Statistics.documents.update statisticsDataId, $set: countAnnotations: countAnnotations if !initializingAnnotations

    removed: (id) =>
      countAnnotations--
      Statistics.documents.update statisticsDataId, $set: countAnnotations: countAnnotations if !initializingAnnotations

  Group.documents.find({},
    fields:
      _id: 1 # We want only id
  ).observeChanges
    added: (id) =>
      countGroups++
      Statistics.documents.update statisticsDataId, $set: countGroups: countGroups if !initializingGroups

    removed: (id) =>
      countGroups--
      Statistics.documents.update statisticsDataId, $set: countGroups: countGroups if !initializingGroups

  Collection.documents.find({},
    fields:
      _id: 1 # We want only id
  ).observeChanges
    added: (id) =>
      countCollections++
      Statistics.documents.update statisticsDataId, $set: countCollections: countCollections if !initializingCollections

    removed: (id) =>
      countCollections--
      Statistics.documents.update statisticsDataId, $set: countCollections: countCollections if !initializingCollections

  BlogPost.documents.find({},
    fields:
      _id: 1 # We want only id
  ).observeChanges
    added: (id) =>
      countBlogPosts++
      Statistics.documents.update statisticsDataId, $set: countBlogPosts: countBlogPosts if !initializingBlogPosts

    removed: (id) =>
      countBlogPosts--
      Statistics.documents.update statisticsDataId, $set: countBlogPosts: countBlogPosts if !initializingBlogPosts

  Statistics.documents.insert
    _id: statisticsDataId
    countPublications: countPublications
    countPersons: countPersons
    countHighlights: countHighlights
    countAnnotations: countAnnotations
    countGroups: countGroups
    countCollections: countCollections
    countBlogPosts: countBlogPosts
    minPublicationDate: minPublicationDate?.toDate()
    maxPublicationDate: maxPublicationDate?.toDate()

  initializingPublications = false
  initializingPersons = false
  initializingHighlights = false
  initializingAnnotations = false
  initializingGroups = false
  initializingCollections = false
  initializingBlogPosts = false

# We map local collection to the collection clients use
Meteor.publish 'statistics', ->
  handle = Statistics.documents.find().observeChanges
    added: (id, fields) =>
      @added 'Statistics', id, fields

    changed: (id, fields) =>
      @changed 'Statistics', id, fields

    removed: (id) =>
      @removed 'Statistics', id

  @ready()

  @onStop ->
    handle.stop()
