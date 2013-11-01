class @Publication extends @Publication
  checkCache: =>
    return if @cached

    if not Storage.exists @filename()
      console.log "Caching PDF for #{ @_id } from the central server"

      pdf = HTTP.get 'http://stage.peerlibrary.org' + @url(),
        timeout: 10000 # ms
        encoding: null # PDFs are binary data

      Storage.save @filename(), pdf.content

    @cached = true
    Publications.update @_id, $set: cached: @cached

    pdf?.content

  process: (pdf, initCallback, textCallback, pageImageCallback, progressCallback) =>
    pdf ?= Storage.open @filename()
    initCallback ?= (numberOfPages) ->
    textCallback ?= (pageNumber, x, y, width, height, direction, text) ->
    pageImageCallback ?= (pageNumber, canvasElement) ->
    progressCallback ?= (progress) ->

    console.log "Processing PDF for #{ @_id }: #{ @filename() }"

    PDF.process pdf, initCallback, textCallback, pageImageCallback, progressCallback

    @processed = true
    Publications.update @_id, $set: processed: @processed

  # A subset of public fields used for search results to optimize transmission to a client
  # This list is applied to PUBLIC_FIELDS to get a subset
  @PUBLIC_SEARCH_RESULTS_FIELDS: ->
    [
      'slug'
      'created'
      'updated'
      'authors'
      'title'
      'numberOfPages'
    ]

  # A set of fields which are public and can be published to the client
  @PUBLIC_FIELDS: ->
    fields:
      slug: 1
      created: 1
      updated: 1
      authors: 1
      title: 1
      numberOfPages: 1
      abstract: 1
      doi: 1
      foreignId: 1
      source: 1
      importing: 1

Meteor.methods
  createPublication: (filename, sha256) ->
    throw new Meteor.Error 403, 'User is not signed in.' unless @userId

    existingPublication = Publications.findOne
      sha256: sha256

    if existingPublication?.importing?
      # We have the publication but nobody has finished uploading it, so let's do it
      Publications.update
        _id: existingPublication._id
      ,
        $addToSet:
          'importing.by':
            person:
              _id: Meteor.personId()
            filename: filename
      id = existingPublication._id
    else if existingPublication?
      # We already have the PDF
      id = existingPublication._id
    else
      # We don't have anything, create a new publication
      id = Publications.insert
        created: moment.utc().toDate()
        updated: moment.utc().toDate()
        source: 'upload'
        importing:
          by: [
            person:
              _id: Meteor.personId()
            filename: filename
          ]
          uploadProgress: 0
          processProgress: 0
          sha256: sha256
        cached: false
        processed: false

    Persons.update
      '_id': Meteor.personId()
    ,
      $addToSet:
        library:
          _id: id

    return id


  uploadPublication: (file) ->
    throw new Meteor.Error 401, 'User is not signed in.' unless @userId
    throw new Meteor.Error 403, 'File is null.' unless file

    publication = Publications.findOne
      _id: file.name # file.options.publicationId
      'importing.by.person._id': Meteor.personId()

    throw new Meteor.Error 403, 'No publication importing.' unless publication

    unless publication.cached

      Storage.saveMeteorFile file, publication.filename()

      Publications.update
        _id: publication._id
      ,
        $max:
          'importing.uploadProgress': file.end / file.size

      if file.end == file.size
        # TODO: Read and hash in chunks, when we will be processing PDFs as well in chunks
        pdf = Storage.open publication.filename()

        hash = new Crypto.SHA256()
        hash.update pdf
        sha256 = hash.finalize()

        unless sha256 == publication.importing.sha256
          throw new Meteor.Error 403, 'Hash does not match.'

        Publications.update
          _id: publication._id
        ,
          $set:
            cached: true
            sha256: sha256

  confirmPublication: (id, metadata) ->
    throw new Meteor.Error 401, 'User is not signed in.' unless @userId

    publication = Publications.findOne
      _id: id
      'importing.by.person._id': Meteor.personId()
      cached: true

    throw new Meteor.Error 403, 'No publication importing.' unless publication

    Publications.update
      _id: publication._id
    ,
      $set:
        _.extend _.pick(metadata or {}, 'authorsRaw', 'title', 'abstract', 'doi'),
          updated: moment.utc().toDate()
      $unset:
        importing: ''

    Persons.update
      _id: Meteor.personId()
    ,
      $addToSet:
        'library':
          _id: publication._id

Meteor.publish 'publications-by-author-slug', (slug) ->
  return unless slug

  author = Persons.findOne
    slug: slug

  return unless author

  Publications.find
    'authors._id': author._id
    cached: true
    processed: true
  ,
    Publication.PUBLIC_FIELDS()

Meteor.publish 'publications-by-id', (id) ->
  return unless id

  Publications.find
    _id: id
    cached: true
    processed: true
  ,
    Publication.PUBLIC_FIELDS()

Meteor.publish 'publications-by-ids', (ids) ->
  return unless ids?.length

  Publications.find
    _id:
      $in: ids
    cached: true
    processed: true
  ,
    Publication.PUBLIC_FIELDS()

Meteor.publish 'my-publications', ->
  # There are moments when two observes are observing mostly similar list
  # of publications ids so it could happen that one is changing or removing
  # publication just while the other one is adding, so we are making sure
  # using currentLibrary variable that we have a consistent view of the
  # publications we published
  currentLibrary = {}
  currentPersonId = null # Just for asserts
  handlePublications = null

  removePublications = (ids) =>
    for id of ids when currentLibrary[id]
      delete currentLibrary[id]
      @removed 'Publications', id

  publishPublications = (newLibrary) =>
    newLibrary ||= []

    added = {}
    added[id] = true for id in _.difference newLibrary, _.keys(currentLibrary)
    removed = {}
    removed[id] = true for id in _.difference _.keys(currentLibrary), newLibrary

    # Optimization, happens when a publication document is first deleted and
    # then removed from the library list in the person document
    if _.isEmpty(added) and _.isEmpty(removed)
      return

    oldHandlePublications = handlePublications
    handlePublications = Publications.find(
      _id:
        $in: newLibrary
      # TODO: Should be set as well if we have PDF locally
      # cached: true
      processed: true
    ,
      Publication.PUBLIC_FIELDS()
    ).observeChanges
      added: (id, fields) =>
        return if currentLibrary[id]
        currentLibrary[id] = true

        # We add only the newly added ones, others were added already before
        @added 'Publications', id, fields if added[id]

      changed: (id, fields) =>
        return if not currentLibrary[id]

        @changed 'Publications', id, fields

      removed: (id) =>
        return if not currentLibrary[id]
        delete currentLibrary[id]

        @removed 'Publications', id

    # We stop the handle after we established the new handle,
    # so that any possible changes hapenning in the meantime
    # were still processed by the old handle
    oldHandlePublications.stop() if oldHandlePublications

    # And then we remove those who are not in the library anymore
    removePublications removed

  handlePersons = Persons.find(
    'user._id': @userId
  ,
    fields:
      # id field is implicitly added
      'user._id': 1
      library: 1
  ).observeChanges
    added: (id, fields) =>
      # There should be only one person with the id at every given moment
      assert.equal currentPersonId, null
      assert.equal fields.user._id, @userId

      currentPersonId = id
      publishPublications _.pluck fields.library, '_id'

    changed: (id, fields) =>
      # Person should already be added
      assert.notEqual currentPersonId, null

      publishPublications _.pluck fields.library, '_id'

    removed: (id) =>
      # We cannot remove the person if we never added the person before
      assert.notEqual currentPersonId, null

      handlePublications.stop() if handlePublications
      handlePublications = null

      currentPersonId = null
      removePublications _.pluck currentLibrary, '_id'

  @ready()

  @onStop =>
    handlePersons.stop() if handlePersons
    handlePublications.stop() if handlePublications

Meteor.publish 'my-publications-importing', ->
  Publications.find
    'importing.by.person._id': @personId
  ,
    fields: _.extend Publication.PUBLIC_FIELDS().fields,
      cached: 1
      processed: 1
