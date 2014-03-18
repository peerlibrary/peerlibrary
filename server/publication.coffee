crypto = Npm.require 'crypto'

NUMBER_OF_VERIFICATION_SAMPLES = 3
VERIFICATION_SAMPLE_SIZE = 64

SLUG_MAX_LENGTH = 80

class @Publication extends Publication
  @Meta
    name: 'Publication'
    replaceParent: true
    fields: (fields) =>
      fields.slug.generator = (fields) ->
        if fields.title
          [fields._id, URLify2 fields.title, SLUG_MAX_LENGTH]
        else
          [fields._id, '']
      fields.fullText.generator = (fields) ->
        return [null, null] unless fields.cached
        return [null, null] if fields.processed
        # That we exit if processError is true is important becaus it is used in admin methods to force (re)precessing
        return [null, null] if fields.processError

        try
          return [fields._id, new Publication(fields).process()]
        catch error
          # TODO: What if exception is just because of the concurrent processing? Should we retry? After a delay?

          Publication.documents.update fields._id,
            $set:
              processError:
                error: "#{ error.toString?() or error }"
                stack: error.stack

          Log.error "Error processing PDF: #{ error.stack or error.toString?() or error }"

          return [null, null]

      fields

  checkCache: =>
    return if @cached

    if not Storage.exists @filename()
      Log.info "Caching PDF for #{ @_id } from the central server"

      pdf = HTTP.get 'http://stage.peerlibrary.org' + @url(),
        timeout: 10000 # ms
        encoding: null # PDFs are binary data

      Storage.save @filename(), pdf.content

    @cached = moment.utc().toDate()
    Publication.documents.update @_id, $set: cached: @cached

  process: =>
    currentlyProcessingPublication @_id

    try
      pdf = Storage.open @filename()

      textContents = []

      initCallback = (numberOfPages) =>
        @numberOfPages = numberOfPages

      textContentCallback = (pageNumber, textContent) =>
        textContents.push textContent

      textSegmentCallback = (pageNumber, segment) =>

      pageImageCallback = (pageNumber, canvasElement) =>
        thumbnailCanvas = new PDFJS.canvas 95, 125
        thumbnailContext = thumbnailCanvas.getContext '2d'

        # TODO: Do better image resizing, antialias doesn't really help
        thumbnailContext.antialias = 'subpixel'

        thumbnailContext.drawImage canvasElement, 0, 0, canvasElement.width, canvasElement.height, 0, 0, thumbnailCanvas.width, thumbnailCanvas.height

        Storage.save @thumbnail(pageNumber), thumbnailCanvas.toBuffer()

      progressCallback = (progress) =>

      Log.info "Processing PDF for #{ @_id }: #{ @filename() }"

      PDF.process pdf, initCallback, textContentCallback, textSegmentCallback, pageImageCallback, progressCallback

      assert textContents.length, @numberOfPages

      @fullText = PDFJS.pdfExtractText textContents...

      # TODO: We could also add some additional information (statistics, how long it took and so on)
      @processed = moment.utc().toDate()
      Publication.documents.update @_id,
        $set:
          numberOfPages: @numberOfPages
          processed: @processed
          fullText: @fullText

      # TODO: Maybe we should use instead of GeneratedField just something which is automatically triggered, but we then update multiple fields, or we should allow GeneratedField to return multiple fields?
      return @fullText

    finally
      currentlyProcessingPublication null

  _temporaryFilename: =>
    # We assume that importing contains only this person, see comment in uploadPublication
    assert @importing?[0]?.person?._id
    assert.equal @importing[0].person._id, Meteor.personId()

    Publication._filenamePrefix() + 'tmp' + Storage._path.sep + @importing[0].temporaryFilename + '.pdf'

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
      'createdAt'
      'authors'
      'title'
      'numberOfPages'
      'abstract' # We do not really pass abstract on, just transform it to hasAbstract in search results
      'access'
    ]

  # A set of fields which are public and can be published to the client
  @PUBLIC_FIELDS: ->
    fields:
      slug: 1
      createdAt: 1
      updatedAt: 1
      authors: 1
      title: 1
      numberOfPages: 1
      abstract: 1
      doi: 1
      foreignId: 1
      source: 1
      access: 1

Publication.Meta.collection.allow
  update: (userId, doc) ->
    return false unless userId

    personId = Meteor.personId userId

    # TODO: Check if user has access to changing the publication (reputation points, in permission group)
    personId

# Misuse insert validation to add additional fields on the server before insertion
Publication.Meta.collection.deny
  # We have to disable transformation so that we have
  # access to the document object which will be inserted
  transform: null

  update: (userId, doc) ->
    doc.updatedAt = moment.utc().toDate()

    # We return false as we are not
    # checking anything, just updating fields
    false

Meteor.methods
  'create-publication': (filename, sha256) ->
    check filename, String
    check sha256, String

    throw new Meteor.Error 401, "User not signed in." unless Meteor.personId()

    existingPublication = Publication.documents.findOne
      sha256: sha256

    # Filter importing to contain only this person
    if existingPublication?.importing
      existingPublication.importing = _.filter existingPublication.importing, (importingBy) ->
        return importingBy.person._id is Meteor.personId()

    already = false
    if existingPublication?._id in _.pluck Meteor.person()?.library, '_id'
      # This person already has the publication in library
      id = existingPublication._id
      verify = false
      already = true

    else if existingPublication?.importing?[0]
      # This person already has an import, so ask for confirmation or upload
      # TODO: Should we set here filename to possible new filename? So that if user is uploading a file again after some time with new filename it works with new?
      id = existingPublication._id
      verify = !!existingPublication.cached

    else if existingPublication?
      # We have the publication, so add person to it
      Publication.documents.update
        _id: existingPublication._id
        'importing.person._id':
          $ne: Meteor.personId()
      ,
        $addToSet:
          importing:
            person:
              _id: Meteor.personId()
            filename: filename
            temporaryFilename: Random.id()
      # TODO: We could check here if we updated anything, if we did not, then it seems user was just added to importing in parallel, so we could go to the case above (and reorder code a bit)

      # If we have the file, ask for verification. Otherwise, ask for upload
      id = existingPublication._id
      verify = !!existingPublication.cached

    else
      # We don't have anything, so create a new publication and ask for upload
      id = Publication.documents.insert
        createdAt: moment.utc().toDate()
        updatedAt: moment.utc().toDate()
        source: 'import'
        importing: [
          person:
            _id: Meteor.personId()
          filename: filename
          temporaryFilename: Random.id()
        ]
        sha256: sha256
        metadata: false
      verify = false

    samples = if verify then existingPublication._verificationSamples Meteor.personId() else null

    # Return
    publicationId: id
    verify: verify
    already: already
    samples: samples

  'upload-publication': (file, options) ->
    check file, MeteorFile
    check options, Match.ObjectIncluding
      publicationId: String

    throw new Meteor.Error 401, "User not signed in." unless Meteor.personId()

    publication = Publication.documents.findOne
      _id: options.publicationId
      'importing.person._id': Meteor.personId()
      cached:
        $exists: false
    ,
      fields:
        # Ensure that importing contains only this person
        'importing.$': 1
        sha256: 1
        source: 1

    # File maybe finished by somebody else, or wrong publicationId, or something else.
    # If the file was maybe finished by somebody else, we do not want really to continue writing
    # into temporary files because maybe they were already removed.
    throw new Meteor.Error 400, "Error uploading file. Please retry." unless publication

    # TODO: Check if reported offset and size are reasonable, offset < size, and size must not be too large (we should have some max size limit)
    # TODO: Before writing verify that chunk size is as expected (we want to enforce this as a constant both on client size) and that buffer has the chunk size length, last chunk is a special case
    Storage.saveMeteorFile file, publication._temporaryFilename()

    if file.end == file.size
      # TODO: Read and hash in chunks, when we will be processing PDFs as well in chunks
      pdf = Storage.open publication._temporaryFilename()

      hash = new Crypto.SHA256()
      hash.update pdf
      sha256 = hash.finalize()

      unless sha256 == publication.sha256
        throw new Meteor.Error 403, "Hash of uploaded file does not match hash provided initially."

      unless publication.cached
        # Upload is being finished for the first time, so move it to permanent location
        Storage.rename publication._temporaryFilename(), publication.filename()
        Publication.documents.update
          _id: publication._id
        ,
          $set:
            cached: moment.utc().toDate()
            size: file.size

      # Hash was verified, so add it to uploader's library
      Person.documents.update
        '_id': Meteor.personId()
      ,
        $addToSet:
          library:
            _id: publication._id

  'verify-publication': (publicationId, samplesData) ->
    check publicationId, String
    check samplesData, [Uint8Array]

    throw new Meteor.Error 401, "User not signed in." unless Meteor.personId()

    publication = Publication.documents.findOne
      _id: publicationId
      cached:
        $exists: true

    throw new Meteor.Error 400, "Error verifying file. Please retry." unless publication
    throw new Meteor.Error 400, "Invalid number of samples." unless samplesData?.length == NUMBER_OF_VERIFICATION_SAMPLES

    publicationFile = Storage.open publication.filename()
    serverSamples = publication._verificationSamples Meteor.personId()

    verified = _.every _.map serverSamples, (serverSample, index) ->
      clientSampleData = samplesData[index]
      serverSampleData = new Uint8Array publicationFile.slice serverSample.offset, serverSample.offset + serverSample.size
      _.isEqual clientSampleData, serverSampleData

    throw new Meteor.Error 403, "Verification failed." unless verified

    # Samples were verified, so add it to person's library
    Person.documents.update
      '_id': Meteor.personId()
    ,
      $addToSet:
        library:
          _id: publication._id

# TODO: Should we use try/except around the code so that if there is any exception we stop handlers?
publishUsingMyLibrary = (publish, selector, options) ->
  # There are moments when two observes are observing mostly similar list
  # of publications ids so it could happen that one is changing or removing
  # publication just while the other one is adding, so we are making sure
  # using currentPublications variable that we have a consistent view of the
  # publications we published
  currentPublications = {}
  handlePublications = null

  publishPublications = (newIsAdmin, newLibrary) =>
    newLibrary ||= []

    initializing = true
    initializedPublications = []

    oldHandlePublications = handlePublications
    handlePublications = Publication.documents.find(selector(newIsAdmin, newLibrary), options).observeChanges
      added: (id, fields) =>
        initializedPublications.push id if initializing

        return if currentPublications[id]
        currentPublications[id] = true

        publish.added 'Publications', id, fields

      changed: (id, fields) =>
        return if not currentPublications[id]

        publish.changed 'Publications', id, fields

      removed: (id) =>
        return if not currentPublications[id]
        delete currentPublications[id]

        publish.removed 'Publications', id

    initializing = false

    # We stop the handle after we established the new handle,
    # so that any possible changes hapenning in the meantime
    # were still processed by the old handle
    oldHandlePublications.stop() if oldHandlePublications

    # And then we remove those which are not published anymore
    for id in _.difference _.keys(currentPublications), initializedPublications
      delete currentPublications[id]
      publish.removed 'Publications', id

  currentPersonId = null # Just for asserts

  if publish.personId
    handlePersons = Person.documents.find(
      _id: publish.personId
    ,
      fields:
        # _id field is implicitly added
        isAdmin: 1
        library: 1
      transform: null # We are only interested in data
    ).observe
      added: (person) =>
        # There should be only one person with the id at every given moment
        assert.equal currentPersonId, null

        currentPersonId = person._id
        publishPublications person.isAdmin, _.pluck person.library, '_id'

      changed: (newPerson, oldPerson) =>
        # Person should already be added
        assert.equal currentPersonId, newPerson._id

        publishPublications newPerson.isAdmin, _.pluck newPerson.library, '_id'

      removed: (oldPerson) =>
        # We cannot remove the person if we never added the person before
        assert.equal currentPersonId, oldPerson._id

        currentPersonId = null
        publishPublications false, []

  # If we get to here and currentPersonId was not set when initializing,
  # we call publishPublications with empty list so that possibly something
  # is published. If later on person is added, publishPublications will be
  # simply called again.
  publishPublications false, [] unless currentPersonId

  publish.ready()

  publish.onStop =>
    handlePersons.stop() if handlePersons
    handlePublications.stop() if handlePublications

Meteor.publish 'publications-by-author-slug', (slug) ->
  check slug, String

  return unless slug

  currentPublications = {}
  handlePublications = null

  publishPublications = (authorId, newIsAdmin, newLibrary) =>
    newLibrary ||= []

    initializing = true
    initializedPublications = []

    oldHandlePublications = handlePublications
    if authorId
      handlePublications = Publication.documents.find(
        if newIsAdmin
          'authors._id': authorId
          cached:
            $exists: true
        else
          'authors._id': authorId
          cached:
            $exists: true
          $or: [
            processed:
              $exists: true
          ,
            _id:
              $in: newLibrary
          ]
      ,
        Publication.PUBLIC_FIELDS()
      ).observeChanges
        added: (id, fields) =>
          initializedPublications.push id if initializing

          return if currentPublications[id]
          currentPublications[id] = true

          @added 'Publications', id, fields

        changed: (id, fields) =>
          return if not currentPublications[id]

          @changed 'Publications', id, fields

        removed: (id) =>
          return if not currentPublications[id]
          delete currentPublications[id]

          @removed 'Publications', id

    initializing = false

    # We stop the handle after we established the new handle,
    # so that any possible changes hapenning in the meantime
    # were still processed by the old handle
    oldHandlePublications.stop() if oldHandlePublications

    # And then we remove those which are not published anymore
    for id in _.difference _.keys(currentPublications), initializedPublications
      delete currentPublications[id]
      @removed 'Publications', id

  currentPersonId = null # Just for asserts
  lastIsAdmin = false
  lastLibrary = []

  if @personId
    handlePersons = Person.documents.find(
      _id: @personId
    ,
      fields:
        # _id field is implicitly added
        isAdmin: 1
        library: 1
    ).observeChanges
      added: (id, fields) =>
        # There should be only one person with the id at every given moment
        assert.equal currentPersonId, null

        currentPersonId = id
        lastIsAdmin = fields.isAdmin
        lastLibrary = _.pluck fields.library, '_id'
        publishPublications currentAuthorId, lastIsAdmin, lastLibrary

      changed: (id, fields) =>
        # Person should already be added
        assert.equal currentPersonId, id

        lastIsAdmin = fields.isAdmin if _.has fields, 'isAdmin'
        lastLibrary = _.pluck fields.library, '_id' if _.has fields, 'library'
        publishPublications currentAuthorId, lastIsAdmin, lastLibrary

      removed: (id) =>
        # We cannot remove the person if we never added the person before
        assert.equal currentPersonId, id

        currentPersonId = null
        lastIsAdmin = false
        lastLibrary = []
        publishPublications currentAuthorId, lastIsAdmin, lastLibrary

  currentAuthorId = null # Just for asserts

  handleAuthors = Person.documents.find(
    slug: slug
  ,
    fields:
      _id: 1 # We want only id
  ).observeChanges
    added: (id, fields) =>
      # There should be only one person with the id at every given moment
      assert.equal currentAuthorId, null

      currentAuthorId = id
      publishPublications currentAuthorId, lastIsAdmin, lastLibrary

    removed: (id) =>
      # We cannot remove the person if we never added the person before
      assert.equal currentAuthorId, id

      currentAuthorId = null
      publishPublications currentAuthorId, lastIsAdmin, lastLibrary

  @ready()

  @onStop =>
    handlePersons.stop() if handlePersons
    handleAuthors.stop() if handleAuthors
    handlePublications.stop() if handlePublications

Meteor.publish 'publications-by-id', (id) ->
  check id, String

  return unless id

  publishUsingMyLibrary @, (isAdmin, library) =>
    if isAdmin
      _id: id
      cached:
        $exists: true
    else
      _id: id
      cached:
        $exists: true
      $or: [
        processed:
          $exists: true
      ,
        _id:
          $in: library
      ]
  ,
    Publication.PUBLIC_FIELDS()

Meteor.publish 'publications-by-ids', (ids) ->
  check ids, [String]

  return unless ids?.length

  publishUsingMyLibrary @, (isAdmin, library) =>
    if isAdmin
      _id:
        $in: ids
      cached:
        $exists: true
    else
      _id:
        $in: ids
      cached:
        $exists: true
      $or: [
        processed:
          $exists: true
      ,
        _id:
          $in: library
      ]
  ,
    Publication.PUBLIC_FIELDS()

Meteor.publish 'my-publications', ->
  # TODO: isAdmin is not really used, so this publish is not as optimized as it should be, probably we should make publishUsingMyLibrary a more general query constructor
  publishUsingMyLibrary @, (isAdmin, library) =>
    _id:
      $in: library
    cached:
      $exists: true
  ,
    Publication.PUBLIC_FIELDS()

# We could try to combine my-publications and my-publications-importing,
# but it is easier to have two and leave to Meteor to merge them together,
# because we are using $ in fields
Meteor.publish 'my-publications-importing', ->
  Publication.documents.find
    'importing.person._id': @personId
    cached:
      $exists: true
  ,
    fields: _.extend Publication.PUBLIC_FIELDS().fields,
      # TODO: We should not push temporaryFile to the client
      # Ensure that importing contains only this person
      'importing.$': 1
