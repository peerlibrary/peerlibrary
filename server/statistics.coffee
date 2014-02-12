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

  Publications.find({},
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

      Statistics.update statisticsDataId, $set: changed if !initializingPublications

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

      Statistics.update statisticsDataId, $set: changed if !initializingPublications and _.size changed

    removed: (id) =>
      countPublications--
      Statistics.update statisticsDataId, $set: countPublications: countPublications if !initializingPublications

      # We ignore removed publications for minPublicationDate and maxPublicationDate.
      # This much simplifies the code and there is not really a big drawback because of this.

  Persons.find({},
    fields:
      _id: 1 # We want only id
  ).observeChanges
    added: (id) =>
      countPersons++
      Statistics.update statisticsDataId, $set: countPersons: countPersons if !initializingPersons

    removed: (id) =>
      countPersons--
      Statistics.update statisticsDataId, $set: countPersons: countPersons if !initializingPersons

  Highlights.find({},
    fields:
      _id: 1 # We want only id
  ).observeChanges
    added: (id) =>
      countHighlights++
      Statistics.update statisticsDataId, $set: countHighlights: countHighlights if !initializingHighlights

    removed: (id) =>
      countHighlights--
      Statistics.update statisticsDataId, $set: countHighlights: countHighlights if !initializingHighlights

  Annotations.find({},
    fields:
      _id: 1 # We want only id
  ).observeChanges
    added: (id) =>
      countAnnotations++
      Statistics.update statisticsDataId, $set: countAnnotations: countAnnotations if !initializingAnnotations

    removed: (id) =>
      countAnnotations--
      Statistics.update statisticsDataId, $set: countAnnotations: countAnnotations if !initializingAnnotations

  Statistics.insert
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
  handle = Statistics.find().observeChanges
    added: (id, fields) =>
      @added 'Statistics', id, fields

    changed: (id, fields) =>
      @changed 'Statistics', id, fields

    removed: (id) =>
      @removed 'Statistics', id

  @ready()

  @onStop ->
    handle.stop()
