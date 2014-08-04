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
        # That we exit if processError is true is important because it is used in admin methods to force (re)precessing
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

          Log.error "Error processing publication: #{ error.stack or error.toString?() or error }"

          return [null, null]

      fields.annotationsCount.generator = (fields) ->
        [fields._id, fields.annotations?.length or 0]

      fields

  @foreignSources: ->
    [
      'arXiv'
      'FSM'
    ]

  @_arXivFilename: (arXivId) ->
    # TODO: Verify that id is not insecure
    'arxiv' + Storage._path.sep + arXivId + '.pdf'

  @_FSMFilename: (fsmId) ->
    # TODO: Verify that id is not insecure
    'FSM' + Storage._path.sep + fsmId + '.tei'

  @foreignFilename: (source, foreignId) ->
    filename = switch source
      when 'arXiv' then Publication._arXivFilename foreignId
      when 'FSM' then Publication._FSMFilename foreignId
      else null

    return unless filename

    Publication._filenamePrefix() + filename

  foreignFilename: =>
    @constructor.foreignFilename @source, @foreignId

  storageForeignUrl: =>
    Storage.url @foreignFilename()

  process: =>
    switch @mediaType
      when 'pdf' then @processPDF()
      when 'tei' then @processTEI()
      else throw new Error "Unsupported media type: #{ @mediaType }"

  processPDF: =>
    currentlyProcessingPublication @_id

    try
      pdf = Storage.open @cachedFilename()

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

      Log.info "Processing PDF for #{ @_id }: #{ @cachedFilename() }"

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

  processTEI: =>
    tei = Storage.open @cachedFilename()

    $ = cheerio.load tei
    @fullText = $.root().text().replace(/\s+/g, ' ').trim()

    # TODO: We could also add some additional information (statistics, how long it took and so on)
    @processed = moment.utc().toDate()
    Publication.documents.update @_id,
      $set:
        processed: @processed
        fullText: @fullText

    # TODO: Maybe we should use instead of GeneratedField just something which is automatically triggered, but we then update multiple fields, or we should allow GeneratedField to return multiple fields?
    @fullText

  _importingFilename: (index=0) =>
    assert @importing?[index]?.importingId

    Publication._filenamePrefix() + 'tmp' + Storage._path.sep + @importing[index].importingId + '.pdf'

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

  # A set of fields which are public and can be published to the client
  # cachedId field is availble for open access publications, if user has the publication in the library, or is a private publication
  @PUBLISH_FIELDS: ->
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
      mediaType: 1
      access: 1
      annotationsCount: 1
      readPersons: 1
      readGroups: 1
      maintainerPersons: 1
      maintainerGroups: 1
      adminPersons: 1
      adminGroups: 1

  # A subset of public fields used for search results to optimize transmission to a client
  @PUBLISH_SEARCH_RESULTS_FIELDS: ->
    fields: _.pick @PUBLISH_FIELDS().fields, [
      'slug'
      'createdAt'
      'authors'
      'title'
      'numberOfPages'
      'abstract' # We do not really pass abstract on, just transform it to hasAbstract in search results
      'access'
      'annotationsCount'
    ]

  # A subset of public fields used for catalog results
  @PUBLISH_CATALOG_FIELDS = @PUBLISH_SEARCH_RESULTS_FIELDS

registerForAccess Publication

Meteor.methods
  'create-publication': methodWrap (filename, sha256) ->
    check filename, String
    check sha256, SHA256String

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    existingPublication = Publication.documents.findOne
      sha256: sha256

    # Filter importing to contain only this person
    if existingPublication?.importing
      existingPublication.importing = _.filter existingPublication.importing, (importingBy) ->
        return importingBy.person._id is person._id

    already = false
    if existingPublication?._id in _.pluck person.library, '_id'
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
      createdAt = moment.utc().toDate()
      Publication.documents.update
        _id: existingPublication._id
        'importing.person._id':
          $ne: person._id
      ,
        $addToSet:
          importing:
            createdAt: createdAt
            updatedAt: createdAt
            person:
              _id: person._id
            filename: filename
            importingId: Random.id()
      # TODO: We could check here if we updated anything, if we did not, then it seems user was just added to importing in parallel, so we could go to the case above (and reorder code a bit)

      # If we have the file, ask for verification. Otherwise, ask for upload
      id = existingPublication._id
      verify = !!existingPublication.cached

    else
      # We don't have anything, so create a new publication and ask for upload
      createdAt = moment.utc().toDate()
      id = Publication.documents.insert Publication.applyDefaultAccess person._id,
        createdAt: createdAt
        updatedAt: createdAt
        source: 'import'
        importing: [
          createdAt: createdAt
          updatedAt: createdAt
          person:
            _id: person._id
          filename: filename
          importingId: Random.id()
        ]
        cachedId: Random.id()
        mediaType: 'pdf'
        sha256: sha256
      verify = false

    samples = if verify then existingPublication._verificationSamples person._id else null

    # Return
    publicationId: id
    verify: verify
    already: already
    samples: samples

  'upload-publication': methodWrap (file, options) ->
    check file, MeteorFile
    check options, Match.ObjectIncluding
      publicationId: DocumentId

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    publication = Publication.documents.findOne
      _id: options.publicationId
      'importing.person._id': person._id
      cached:
        $exists: false
    ,
      fields:
        # Ensure that importing contains only this person
        'importing.$': 1
        sha256: 1
        cachedId: 1
        mediaType: 1

    # File maybe finished by somebody else, or wrong publicationId, or something else.
    # If the file was maybe finished by somebody else, we do not want really to continue writing
    # into temporary files because maybe they were already removed.
    throw new Meteor.Error 400, "Error uploading file. Please retry." unless publication

    # TODO: Check if reported offset and size are reasonable, offset < size, and size must not be too large (we should have some max size limit)
    # TODO: Before writing verify that chunk size is as expected (we want to enforce this as a constant both on client size) and that buffer has the chunk size length, last chunk is a special case
    Storage.saveMeteorFile file, publication._importingFilename()

    Publication.documents.update
      _id: publication._id
      'importing.person._id': person._id
    ,
      $set:
        'importing.$.updatedAt': moment.utc().toDate()

    if file.end == file.size
      # TODO: Read and hash in chunks, when we will be processing PDFs as well in chunks
      pdf = Storage.open publication._importingFilename()

      hash = new Crypto.SHA256()
      hash.update pdf
      sha256 = hash.finalize()

      unless sha256 == publication.sha256
        throw new Meteor.Error 400, "Hash of uploaded file does not match hash provided initially."

      unless publication.cached
        # Upload is being finished for the first time, so move it to permanent location
        Storage.rename publication._importingFilename(), publication.cachedFilename()
        Publication.documents.update
          _id: publication._id
        ,
          $set:
            cached: moment.utc().toDate()
            size: file.size

      # Remove all other partially uploaded files, if there are any
      for importing, i in Publication.documents.findOne(_id: options.publicationId).importing
        filename = publication._importingFilename i
        try
          Storage.remove filename
        catch error
          # We ignore any error when removing partially uploaded files

      # Hash was verified, so add it to uploader's library
      Person.documents.update
        _id: person._id
        'library._id':
          $ne: publication._id
      ,
        $addToSet:
          library:
            _id: publication._id

  'verify-publication': methodWrap (publicationId, samplesData) ->
    check publicationId, DocumentId
    check samplesData, [Uint8Array]

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    publication = Publication.documents.findOne
      _id: publicationId
      cached:
        $exists: true

    throw new Meteor.Error 400, "Error verifying file. Please retry." unless publication
    throw new Meteor.Error 400, "Invalid number of samples." unless samplesData?.length == NUMBER_OF_VERIFICATION_SAMPLES

    publicationFile = Storage.open publication.cachedFilename()
    serverSamples = publication._verificationSamples person._id

    verified = _.every _.map serverSamples, (serverSample, index) ->
      clientSampleData = samplesData[index]
      serverSampleData = new Uint8Array publicationFile.slice serverSample.offset, serverSample.offset + serverSample.size
      _.isEqual clientSampleData, serverSampleData

    throw new Meteor.Error 400, "Verification failed." unless verified

    # Samples were verified, so add it to person's library
    Person.documents.update
      '_id': person._id
      'library._id':
        $ne: publication._id
    ,
      $addToSet:
        library:
          _id: publication._id

  # TODO: Use this code on the client side as well
  'publication-set-title': methodWrap (publicationId, title) ->
    check publicationId, DocumentId
    check title, NonEmptyString

    person = Meteor.person()
    throw new Meteor.Error 401, "User not signed in." unless person

    publication = Publication.documents.findOne Publication.requireReadAccessSelector(person,
      _id: publicationId
    )
    throw new Meteor.Error 400, "Invalid publication." unless publication

    Publication.documents.update Publication.requireMaintainerAccessSelector(person,
      _id: publication._id
    ),
      $set:
        title: title

Meteor.publish 'publications', (limit, filter, sortIndex) ->
  check limit, PositiveNumber
  check filter, OptionalOrNull String
  check sortIndex, OptionalOrNull Number
  check sortIndex, Match.Where ->
    not _.isNumber(sortIndex) or 0 <= sortIndex < Publication.PUBLISH_CATALOG_SORT.length

  findQuery = {}
  findQuery = createQueryCriteria(filter, 'title') if filter

  sort = if _.isNumber sortIndex then Publication.PUBLISH_CATALOG_SORT[sortIndex].sort else null

  @related (person) ->
    restrictedFindQuery = Publication.requireReadAccessSelector person, findQuery

    searchPublish @, 'publications', [filter, sortIndex],
      cursor: Publication.documents.find restrictedFindQuery,
        limit: limit
        fields: Publication.PUBLISH_CATALOG_FIELDS().fields
        sort: sort
      added: (id, fields) =>
        fields.hasAbstract = !!fields.abstract
        delete fields.abstract
        fields
      changed: (id, fields) =>
        if 'abstract' of fields
          fields.hasAbstract = !!fields.abstract
          delete fields.abstract
        fields
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: _.extend Publication.readAccessPersonFields()

Meteor.publish 'publications-by-author-slug', (slug) ->
  check slug, NonEmptyString

  @related (author, person) ->
    return unless author?._id

    Publication.documents.find Publication.requireReadAccessSelector(person,
      'authors._id': author._id
    ),
      Publication.PUBLISH_FIELDS()
  ,
    Person.documents.find
      $or: [
        slug: slug
      ,
        _id: slug
      ]
    ,
      fields:
        _id: 1 # We want only id
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: Publication.readAccessPersonFields()

Meteor.publish 'publications-by-id', (publicationId) ->
  check publicationId, DocumentId

  @related (person) ->
    Publication.documents.find Publication.requireReadAccessSelector(person,
      _id: publicationId
    ),
      Publication.PUBLISH_FIELDS()
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: Publication.readAccessPersonFields()

# We could try to combine publications-by-id and publications-cached-by-id,
# but it is easier to have two and leave to Meteor to merge them together
Meteor.publish 'publications-cached-by-id', (id) ->
  check id, DocumentId

  @related (person) ->
    Publication.documents.find Publication.requireCacheAccessSelector(person,
      _id: id
    ),
      fields: _.extend Publication.PUBLISH_FIELDS().fields,
        # cachedId field is availble for open access publications, if user has the publication in the library, or is a private publication
        'cachedId': 1
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: Publication.readAccessPersonFields()

Meteor.publish 'my-publications', ->
  @related (person) ->
    return unless person?.library

    Publication.documents.find Publication.requireReadAccessSelector(person,
      _id:
        $in: _.pluck person.library, '_id'
    ),
      Publication.PUBLISH_FIELDS()
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: _.extend Publication.readAccessPersonFields(),
        library: 1

# Use use this publish endpoint so that users can see their own filename
# of the imported file, before a publication has metadata.
# We could try to combine my-publications and my-publications-importing,
# but it is easier to have two and leave to Meteor to merge them together,
# because we are using $ in fields.
Meteor.publish 'my-publications-importing', ->
  @related (person) ->
    return unless person?._id

    Publication.documents.find Publication.requireReadAccessSelector(person,
      'importing.person._id': person._id
    ),
      fields: _.extend Publication.PUBLISH_FIELDS().fields,
        # TODO: We should not push temporaryFile to the client
        # Ensure that importing contains only this person
        'importing.$': 1
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: Publication.readAccessPersonFields()
