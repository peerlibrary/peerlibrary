if Meteor.settings.AWS
  AWS.config.update
    accessKeyId: Meteor.settings.AWS.accessKeyId
    secretAccessKey: Meteor.settings.AWS.secretAccessKey
else
  Log.warn "AWS settings missing, syncing arXiv PDF cache will not work"

# It seems there are no subject classes
ARXIV_OLD_ID_REGEX = /(?:\/|\\)([a-z-]+)(\d+)\.pdf$/i
# It seems there are no versions in PDF filenames
ARXIV_NEW_ID_REGEX = /(?:\/|\\)([\d.]+)\.pdf$/i
# From http://export.arxiv.org/oai2?verb=Identify
ARXIV_EARLIEST_DATESTAMP = moment.utc('2007-05-23')

ARXIV_ACCENTS =
  '''\\"A''': 'Ä', '''\\"a''': 'ä', '''\\'A''': 'Á', '''\\'a''': 'á', '''\\^A''': 'Â', '''\\^a''': 'â', '''\\`A''': 'À', '''\\`a''': 'à', '''\\~A''': 'Ã', '''\\~a''': 'ã'
  '''\\c{C}''': 'Ç', '''\\c{c}''': 'ç'
  '''\\"E''': 'Ë', '''\\"e''': 'ë', '''\\'E''': 'É', '''\\'e''': 'é', '''\\^E''': 'Ê', '''\\^e''': 'ê', '''\\`E''': 'È', '''\\`e''': 'è'
  '''\\"I''': 'Ï', '''\\"i''': 'ï', '''\\'I''': 'Í', '''\\'i''': 'í', '''\\^I''': 'Î', '''\\^i''': 'î', '''\\`I''': 'Ì', '''\\`i''': 'ì'
  '''\\~N''': 'Ñ', '''\\~n''': 'ñ'
  '''\\"O''': 'Ö', '''\\"o''': 'ö', '''\\'O''': 'Ó', '''\\'o''': 'ó', '''\\^O''': 'Ô', '''\\^o''': 'ô', '''\\`O''': 'Ò', '''\\`o''': 'ò', '''\\~O''': 'Õ', '''\\~o''': 'õ'
  '''\\"U''': 'Ü', '''\\"u''': 'ü', '''\\'U''': 'Ú', '''\\'u''': 'ú', '''\\^U''': 'Û', '''\\^u''': 'û', '''\\`U''': 'Ù', '''\\`u''': 'ù'
  '''\\"Y''': 'Ÿ', '''\\"y''': 'ÿ', '''\\'Y''': 'Ý', '''\\'y''': 'ý'
  '''{\\AA}''': 'Å', '''{\\aa}''': 'å', '''{\\ae}''': 'æ', '''{\\AE}''': 'Æ', '''{\\L}''': 'Ł', '''{\\l}''': 'ł'
  '''{\\o}''': 'ø', '''{\\O}''': 'Ø', '''{\\OE}''': 'Œ', '''{\\oe}''': 'œ', '''{\\ss}''': 'ß'

class @ArXivPDF extends ArXivPDF
  @Meta
    name: 'ArXivPDF'
    replaceParent: true

  # A set of fields which are public and can be published to the client
  @PUBLIC_FIELDS: ->
    fields: {} # All, only admins have access

randomTimestamp = ->
  moment.utc().subtract('hours', Random.fraction() * 24 * 100).toDate()

Meteor.methods
  'sample-data': ->
    throw new Meteor.Error 403, "Permission denied" unless Meteor.person()?.isAdmin

    @unblock()

    Meteor.call 'sync-arxiv-metadata'
    Meteor.call 'sync-local-pdf-cache'

  'process-pdfs': ->
    throw new Meteor.Error 403, "Permission denied" unless Meteor.person()?.isAdmin

    # To force reprocessing, we first set processError to true everywhere to assure there will be
    # change afterwards when we unset it. We set to true so that value is still true and processing
    # is not already triggered (but only when we unset the field).
    Publication.documents.update
      processed:
        $exists: false
    ,
      $set:
        processError: true
    ,
      multi: true
    Publication.documents.update
      processed:
        $exists: false
      processError: true
    ,
      $unset:
        processError: ''
    ,
      multi: true

  'reprocess-pdfs': ->
    throw new Meteor.Error 403, "Permission denied" unless Meteor.person()?.isAdmin

    # To force reprocessing, we first set processError to true everywhere to assure there will be
    # change afterwards when we unset it. We set to true so that value is still true and processing
    # is not already triggered (but only when we unset the field).
    Publication.documents.update {},
      $set:
        processError: true
    ,
      multi: true
    Publication.documents.update {},
      $unset:
        processed: ''
        processError: ''
    ,
      multi: true

  'database-update-all': ->
    throw new Meteor.Error 403, "Permission denied" unless Meteor.person()?.isAdmin

    Document.updateAll()

  'sync-arxiv-pdf-cache': ->
    throw new Meteor.Error 403, "Permission denied" unless Meteor.person()?.isAdmin

    @unblock()

    if not Meteor.settings.AWS
      Log.error "AWS settings missing"
      throw new Meteor.Error 500, "AWS settings missing"

    Log.info "Syncing arXiv PDF cache"

    s3 = new AWS.S3()

    list = blocking(s3, s3.listObjects)
      Bucket: 'arxiv'
      Prefix: 'pdf/'
      RequestPayer: 'requester'

    for file in list.Contents
      if not /\.tar$/.test file.Key
        continue

      lastModified = moment.utc file.LastModified

      fileObj =
        key: file.Key
        lastModified: lastModified.toDate()
        eTag: file.ETag.replace /^"|"$/g, '' # It has " at the start and the end
        size: file.Size

      if ArXivPDF.documents.find(fileObj, limit: 1).count() != 0
        continue

      processPDF = (fun, props, pdf) ->
        match = ARXIV_OLD_ID_REGEX.exec props.path
        if match
          id = match[1] + '/' + match[2]
        else
          match = ARXIV_NEW_ID_REGEX.exec props.path
          if match
            id = match[1]
          else
            Log.error "Invalid filename #{ props.path }"
            throw new Meteor.Error 500, "Invalid filename #{ props.path }"

        ArXivPDF.documents.update fileObj._id,
          $addToSet:
            PDFs:
              id: id
              path: props.path
              size: props.size
              mtime: moment.utc(props.mtime).toDate()
        fun id, pdf

      finishPDF = ->
        ArXivPDF.documents.update fileObj._id, $set: processingEnd: moment.utc().toDate()

      Meteor.bindEnvironment processPDF, ((e) -> throw e), @
      Meteor.bindEnvironment finishPDF, ((e) -> throw e), @

      processTar = blocking (key, fun, cb) ->
        finished = false
        counter = 0

        finalCallback = ->
          finishPDF()
          cb null

        processPDFWrapped = (fun, props, pdf) ->
          counter++
          processPDF fun, props, pdf
          counter--
          if finished and counter == 0
            finalCallback()

        Log.info "Processing tar: #{ key }"

        fileObj.processingStart = moment.utc().toDate()
        fileObj._id = ArXivPDF.documents.insert fileObj

        s3.getObject(
          Bucket: 'arxiv'
          Key: key
          RequestPayer: 'requester'
        ).createReadStream().pipe(
          tar.Parse()
        ).on('ignoredEntry', (entry) ->
          Log.error "Ignored entry in #{ key } tar file: #{ entry.props }"
        ).on('entry', (entry) ->
          if entry.props.type != tar.types.File
            return

          buffer = new Buffer entry.props.size
          offset = 0

          entry.on 'data', (chunk) ->
            chunk.copy buffer, offset
            offset += chunk.length
          entry.on 'end', ->
            assert.equal offset, entry.props.size, "#{ offset }, #{ entry.props.size }"
            processPDFWrapped fun, entry.props, buffer

        ).on('end', ->
          finished = true
          if counter == 0
            finalCallback()
        )

      processTar file.Key, (id, pdf) ->
        Log.info "Storing PDF: #{ id }"

        Storage.save (Publication._filenamePrefix() + Publication._arXivFilename(id)), pdf

    Log.info "Done"

  'sync-arxiv-metadata': ->
    throw new Meteor.Error 403, "Permission denied" unless Meteor.person()?.isAdmin

    @unblock()

    Log.info "Syncing arXiv metadata"

    # TODO: URL hardcoded - not good
    # TODO: Traverse result pages
    # TODO: Store last fetch timestamp

    page = HTTP.get 'http://export.arxiv.org/oai2?verb=ListRecords&from=2007-05-23&until=2007-05-24&metadataPrefix=arXivRaw',
      timeout: 60000 # ms

    if page.statusCode and page.statusCode != 200
      Log.error "Downloading arXiv metadata failed: #{ page.statusCode }: #{ page.content }"
      throw new Meteor.Error 500, "Downloading arXiv metadata failed: #{ page.statusCode }: #{ page.content }"
    else if page.error
      Log.error page.error
      throw page.error

    page = blocking(xml2js.parseString) page.content

    count = 0

    for recordEntry in page['OAI-PMH'].ListRecords[0].record
      record = recordEntry.metadata?[0].arXivRaw?[0]

      if not record?
        # Using inspect because records can be heavily nested
        Log.warn "Empty record metadata, skipping #{ util.inspect recordEntry, false, null }"
        continue

      # TODO: Really process versions
      createdAt = moment.utc(record.version[0].date[0]).toDate()
      updatedAt = moment.utc(record.version[record.version.length - 1].date[0]).toDate()

      authors = record.authors[0]

      for escaped, character of ARXIV_ACCENTS
        # Hacky find and replace
        # It seems some escaped characters are in additional {}, so we first try this
        authors = authors.split('{' + escaped + '}').join character
        authors = authors.split(escaped).join character

      # Normalizing whitespace
      authors = authors.replace /\s+/g, ' '

      # TODO: Parse affiliations, too
      # To clean nested parentheses
      while true
        authorsCleaned = authors.replace /\([^()]*?\)/g, '' # For now, remove all information about affiliations
        if authorsCleaned == authors
          break
        else
          authors = authorsCleaned

      bad = false

      # We split at : too, so that collaboration information is seen as a separate author (see examples below)
      authors = for author in authors.split /^\s*|\s*[,:]\s*|\s*\band\b\s*|\s*$/i when author
        # To support casses like: F.Foobar and F. Foobar Jr.
        [givenName, familyName] = author.split /\s*([^\s.]+.?)\s*$/

        bad |= not givenName or not familyName

        # Are there still escaped characters?
        bad |= /[\\{}]/.test(givenName) or /[\\{}]/.test(familyName)

        givenName: givenName
        familyName: familyName

      if bad
        # Using inspect because records can be heavily nested
        Log.warn "Could not parse authors, skipping #{ authors }, #{ util.inspect record, false, null }"
        continue

      # Remove collaboration information
      # Examples:
      #   Author One, Author Two, for the ABCD Collaboration
      #   ABCD Collaboration: Author One, Author Two, Author Three
      #   C.Sfienti, M. De Napoli, S. Bianchin, A.S. Botvina, J. Brzychczyk, A. Le Fevre, J. Lukasik, P. Pawlowski, W. Trautmann and the ALADiN2000 Collaboration
      authors = (author for author in authors when not (/collaboration/i.test(author.givenName) or /collaboration/i.test(author.familyName)))

      if authors.length == 0
        # Using inspect because records can be heavily nested
        Log.warn "Empty authors list, skipping #{ util.inspect record, false, null }"
        continue

      for author in authors
        # TODO: We could just define id ourselves, we do not have to do two queries
        id = Person.documents.insert
          user: null
          givenName: author.givenName
          familyName: author.familyName
          work: []
          education: []
          publications: []
        Person.documents.update id,
          $set:
            slug: id
        author._id = id
        author.slug = id

      publication =
        slug: Publication.Meta.fields.slug.generator(title: record.title[0])[1]
        createdAt: createdAt
        updatedAt: updatedAt
        authors: authors
        authorsRaw: record.authors[0]
        title: record.title[0]
        comments: record.comments?[0]
        abstract: record.abstract[0]
        doi: record.doi?[0]
        # TODO: Parse
        # Convers strings like "30C80 (primary), 32A40, 46E22 (secondary)" into ["30C80","32A40","46E22"]
        #msc2010: record['msc-class']?[0].split(/\s*[,;]\s*|\s*\([^)]*\)\s*|\s+/).filter (x) -> x
        # Converts strings like "F.2.2; I.2.7" into ["F.2.2","I.2.7"]
        #acm1998: record['acm-class']?[0].split(/\s*[,;]\s*|\s+/).filter (x) -> x
        foreignId: record.id[0]
        # TODO: Put foreign categories into tags?
        foreignCategories: record.categories[0].split /\s+/
        foreignJournalReference: record['journal-ref']?[0]
        source: 'arXiv'

      # TODO: Deal with this
      #if publication.msc2010?
      # We check if we really converted without "(primary)" and similar strings
      #assert.equal (cls for cls in publication.msc2010 when cls.match(/[()]/)).length, 0, "#{ publication.foreignId }: #{ publication.msc2010 }"

      # TODO: Upsert would be better
      if Publication.documents.find({source: publication.source, foreignId: publication.foreignId}, limit: 1).count() == 0
        id = Publication.documents.insert publication
        for author in publication.authors
          Person.documents.update author._id,
            $addToSet:
              publications:
                _id: id # TODO: Entity resolution
        Log.info "Added #{ publication.source }/#{ publication.foreignId } as #{ id }"
        count++

    Log.info "Done"

  'sync-local-pdf-cache': ->
    throw new Meteor.Error 403, "Permission denied" unless Meteor.person()?.isAdmin

    @unblock()

    Log.info "Syncing local PDF cache"

    count = 0

    Publication.documents.find(cached: {$exists: false}).forEach (publication) ->
      try
        publication.checkCache()
        count++ if publication.cached
      catch error
        Log.error "#{ error }"

    Log.info "Done"

Meteor.publish 'arxiv-pdfs', ->
  currentArXivPDFs = {}
  currentPersonId = null # Just for asserts
  handleArXivPDFs = null

  removeArXivPDFs = =>
    for id of currentArXivPDFs
      delete currentArXivPDFs[id]
      @removed 'ArXivPDFs', id

  publishArXivPDFs = =>
    oldHandleArXivPDFs = handleArXivPDFs
    handleArXivPDFs = ArXivPDF.documents.find(
      {}
    ,
      fields: ArXivPDF.PUBLIC_FIELDS().fields
      sort: [
        ['processingStart', 'desc']
      ]
      limit: 5
    ).observeChanges
      added: (id, fields) =>
        return if currentArXivPDFs[id]
        currentArXivPDFs[id] = true

        @added 'ArXivPDFs', id, fields

      changed: (id, fields) =>
        return if not currentArXivPDFs[id]

        @changed 'ArXivPDFs', id, fields

      removed: (id) =>
        return if not currentArXivPDFs[id]
        delete currentArXivPDFs[id]

        @removed 'ArXivPDFs', id

    # We stop the handle after we established the new handle,
    # so that any possible changes hapenning in the meantime
    # were still processed by the old handle
    oldHandleArXivPDFs.stop() if oldHandleArXivPDFs

  handlePersons = Person.documents.find(
    _id: @personId
    isAdmin: true
  ,
    fields:
      _id: 1 # We want only id
  ).observeChanges
    added: (id, fields) =>
      # There should be only one person with the id at every given moment
      assert.equal currentPersonId, null

      currentPersonId = id
      publishArXivPDFs()

    removed: (id) =>
      # We cannot remove the person if we never added the person before
      assert.notEqual currentPersonId, null

      handleArXivPDFs.stop() if handleArXivPDFs
      handleArXivPDFs = null

      currentPersonId = null
      removeArXivPDFs()

  @ready()

  @onStop =>
    handlePersons.stop() if handlePersons
    handleArXivPDFs.stop() if handleArXivPDFs
