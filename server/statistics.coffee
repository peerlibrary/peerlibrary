# We count only once on the server and update a shared
# local collection to which clients then subscribe

Meteor.startup ->
  statisticsDataId = Random.id()
  initializingPublications = true
  initializingPersons = true
  initializingHighlights = true
  initializingAnnotations = true
  countPublications = 0
  countPersons = 0
  countHighlights = 0
  countAnnotations = 0
  minPublicationDate = null
  maxPublicationDate = null

  Publication.documents.find({},
    fields:
      # id field is implicitly added
      created: 1
  ).observeChanges
    added: (id, fields) =>
      countPublications++

      created = moment.utc fields.created

      changed =
        countPublications: countPublications

      if not minPublicationDate or created < minPublicationDate
        minPublicationDate = created
        changed.minPublicationDate = minPublicationDate.toDate()

      if not maxPublicationDate or created > maxPublicationDate
        maxPublicationDate = created
        changed.maxPublicationDate = maxPublicationDate.toDate()

      Statistics.documents.update statisticsDataId, $set: changed if !initializingPublications

    changed: (id, fields) =>
      return unless fields.created

      created = moment.utc fields.created

      changed = {}

      if created < minPublicationDate
        minPublicationDate = created
        changed.minPublicationDate = created.toDate()

      if created > maxPublicationDate
        maxPublicationDate = created
        changed.maxPublicationDate = created.toDate()

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

  Statistics.documents.insert
    _id: statisticsDataId
    countPublications: countPublications
    countPersons: countPersons
    countHighlights: countHighlights
    countAnnotations: countAnnotations
    minPublicationDate: minPublicationDate?.toDate()
    maxPublicationDate: maxPublicationDate?.toDate()

  initializingPublications = false
  initializingPersons = false
  initializingHighlights = false
  initializingAnnotations = false

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
