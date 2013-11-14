crypto = Npm.require 'crypto'

NUMBER_OF_VERIFICATION_SAMPLES = 3
VERIFICATION_SAMPLE_SIZE = 64

class @Publication extends @Publication
  @MixinMeta (meta) =>
    meta.fields.slug.generator = (fields) ->
      if fields.title
        [fields._id, URLify2 fields.title]
      else
        [fields._id, '']
    meta

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

  _temporaryFullFilename: =>
    # We assume that importing.by contains only this person, see comment in uploadPublication
    assert @importing?.by?[0]?.person?._id
    assert.equal @importing.by[0].person._id, Meteor.personId()

    Publication._filenamePrefix() + 'tmp' + Storage._path.sep + @importing.by[0].temporary + '.pdf'

  _verificationSamples: (personId) =>
    _.map _.range(NUMBER_OF_VERIFICATION_SAMPLES), (num) =>
      hmac = crypto.createHmac 'sha256', Crypto.SECRET_KEY
      hmac.update personId
      hmac.update "#{ @_id }"
      hmac.update "#{ num }"
      digest = hmac.digest 'hex'

      # return
      offset: parseInt(digest, 16) % (@size - VERIFICATION_SAMPLE_SIZE)
      size: VERIFICATION_SAMPLE_SIZE

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
      metadata: 1

Meteor.methods
  createPublication: (filename, sha256) ->
    throw new Meteor.Error 403, "User is not signed in." unless Meteor.personId()

    existingPublication = Publications.findOne
      sha256: sha256

    # Filter importing.by to contain only this person
    if existingPublication?.importing?.by
      existingPublication.importing.by = _.filter existingPublication.importing.by, (importingBy) ->
        return importingBy.person._id is Meteor.personId()

    if existingPublication?.importing?.by?[0]?
      # This person already has an import, so ask for confirmation or upload
      id = existingPublication._id
      verify = existingPublication.cached

    else if existingPublication?._id in _.pluck Meteor.person()?.library, '_id'
      # This person already has the publication in library
      id = null
      verify = false

    else if existingPublication?
      # We have the publication, so add person to it
      Publications.update
        _id: existingPublication._id
        'importing.by.person._id':
          $ne: Meteor.personId()
      ,
        $addToSet:
          'importing.by':
            person:
              _id: Meteor.personId()
            filename: filename
            temporary: Random.id()
            uploadProgress: 0
      # If we have the file, ask for verification. Otherwise, ask for upload
      id = existingPublication._id
      verify = existingPublication.cached

    else
      # We don't have anything, so create a new publication and ask for upload
      id = Publications.insert
        created: moment.utc().toDate()
        updated: moment.utc().toDate()
        source: 'upload'
        importing:
          by: [
            person:
              _id: Meteor.personId()
            filename: filename
            temporary: Random.id()
            uploadProgress: 0
          ]
        sha256: sha256
        cached: false
        metadata: false
        processed: false
      verify = false

    samples = if verify then existingPublication._verificationSamples Meteor.personId() else null

    # return
    publicationId: id
    verify: verify
    samples: samples

  uploadPublication: (file, options) ->
    throw new Meteor.Error 401, "User is not signed in." unless Meteor.personId()
    throw new Meteor.Error 403, "File is null." unless file

    check options.publicationId, String

    publication = Publications.findOne
      _id: options.publicationId
      'importing.by.person._id': Meteor.personId()
    ,
      fields:
        # Ensure that importing.by contains only this person
        'importing.by.$': 1
        'sha256': 1
        'source': 1

    throw new Meteor.Error 403, "No publication importing." unless publication

    Storage.saveMeteorFile file, publication._temporaryFullFilename()

    Publications.update
      _id: publication._id
      'importing.by.person._id': Meteor.personId()
    ,
      $set:
        'importing.by.$.uploadProgress': file.end / file.size

    if file.end == file.size
      # TODO: Read and hash in chunks, when we will be processing PDFs as well in chunks
      pdf = Storage.open publication._temporaryFullFilename()

      hash = new Crypto.SHA256()
      hash.update pdf
      sha256 = hash.finalize()

      unless sha256 == publication.sha256
        throw new Meteor.Error 403, "Hash does not match."

      unless publication.cached
        # Upload is being finished for the first time, so move it to permanent location
        Storage.rename publication._temporaryFullFilename(), publication.filename()
        Publications.update
          _id: publication._id
        ,
          $set:
            cached: true
            size: file.size

      # Hash was verified, so add it to uploader's library
      Persons.update
        '_id': Meteor.personId()
      ,
        $addToSet:
          library:
            _id: publication._id

  verifyPublication: (id, samplesData) ->
    throw new Meteor.Error 401, "User is not signed in." unless Meteor.personId()

    publication = Publications.findOne
      _id: id
      cached: true

    throw new Meteor.Error 403, "No publication importing." unless publication
    throw new Meteor.Error 403, "Number of samples does not match." unless samplesData?.length == NUMBER_OF_VERIFICATION_SAMPLES

    publicationFile = Storage.open publication.filename()
    serverSamples = publication._verificationSamples Meteor.personId()

    verified = _.every _.map serverSamples, (serverSample, index) ->
      clientSampleData = samplesData[index]
      serverSampleData = new Uint8Array publicationFile.slice serverSample.offset, serverSample.offset + serverSample.size
      return _.isEqual clientSampleData, serverSampleData

    if verified
      # Samples were verified, so add it to person's library
      Persons.update
        '_id': Meteor.personId()
      ,
        $addToSet:
          library:
            _id: publication._id

      return true
    else
      throw new Meteor.Error 403, "Verification failed."

Meteor.publish 'publications-by-author-slug', (slug) ->
  return unless slug

  author = Persons.findOne
    slug: slug

  return unless author

  # TODO: Make this reactive
  person = Persons.findOne
    _id: @personId
  ,
    library: 1

  Publications.find
    'authors._id': author._id
    $or: [
      cached: true
      processed: true
    ,
      _id:
        $in: _.pluck person?.library, '_id'
    ]
  ,
    Publication.PUBLIC_FIELDS()

Meteor.publish 'publications-by-id', (id) ->
  return unless id

  # TODO: Make this reactive
  person = Persons.findOne
    _id: @personId
  ,
    library: 1

  Publications.find
    _id: id
    $or: [
      cached: true
      processed: true
    ,
      _id:
        $in: _.pluck person?.library, '_id'
    ]
  ,
    Publication.PUBLIC_FIELDS()

Meteor.publish 'publications-by-ids', (ids) ->
  return unless ids?.length

  # TODO: Make this reactive
  person = Persons.findOne
    _id: @personId
  ,
    library: 1

  Publications.find
    _id:
      $in: ids
    $or: [
      cached: true
      processed: true
    ,
      _id:
        $in: _.pluck person?.library, '_id'
    ]
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
      # Ensure that importing.by contains only this person
      'importing.by.$': 1
