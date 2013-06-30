if Meteor.settings.AWS
  AWS.config.update
    accessKeyId: Meteor.settings.AWS.accessKeyId
    secretAccessKey: Meteor.settings.AWS.secretAccessKey
else
  console.warn "AWS settings missing, syncing arXiv PDF cache will not work"

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

randomUser = ->
  user = Random.choice Meteor.users.find().fetch()

  username: user.username
  fullName: user.profile.firstName + ' ' + user.profile.lastName
  id: user._id

randomTimestamp = ->
  moment.utc().subtract('hours', Random.fraction() * 24 * 100).toDate()

Meteor.methods
  'sync-arxhiv-pdf-cache': ->
    @unblock()

    if not Meteor.settings.AWS
      console.error "AWS settings missing"
      throw new Meteor.Error 500, "AWS settings missing"

    console.log "Syncing arXiv PDF cache"

    s3 = new AWS.S3()

    list = blocking s3, s3.listObjects
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

      if ArXivPDFs.find(fileObj, limit: 1).count() != 0
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
            console.error "Invalid filename #{ props.path }"
            throw new Meteor.Error 500, "Invalid filename #{ props.path }"

        ArXivPDFs.update fileObj._id,
          $addToSet:
            PDFs:
              id: id
              path: props.path
              size: props.size
              mtime: moment.utc(props.mtime).toDate()
        fun id, pdf

      finishPDF = ->
        ArXivPDFs.update fileObj._id, $set: processingEnd: moment.utc().toDate()

      Meteor.bindEnvironment processPDF, ((e) -> throw e), this
      Meteor.bindEnvironment finishPDF, ((e) -> throw e), this

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

        console.log "Processing tar: #{ key }"

        fileObj.processingStart = moment.utc().toDate()
        fileObj._id = ArXivPDFs.insert fileObj

        s3.getObject(
          Bucket: 'arxiv'
          Key: key
          RequestPayer: 'requester'
        ).createReadStream().pipe(
          tar.Parse()
        ).on('ignoredEntry', (entry) ->
          console.error "Ignored entry in #{ key } tar file", entry.props
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
        console.log "Storing PDF: #{ id }"

        Storage.save (Publication._filenamePrefix() + Publication._arXivFilename(id)), pdf

    console.log "Done"

  'sync-arxhiv-metadata': ->
    @unblock()

    console.log "Syncing arXiv metadata"

    # TODO: URL hardcoded - not good
    # TODO: Traverse result pages
    # TODO: Store last fetch timestamp

    page = Meteor.http.get 'http://export.arxiv.org/oai2?verb=ListRecords&from=2007-05-23&until=2007-05-24&metadataPrefix=arXivRaw',
      timeout: 60000 # ms

    if page.statusCode and page.statusCode != 200
      console.error "Downloading arXiv metadata failed: #{ page.statusCode }", page.content
      throw new Meteor.Error 500, "Downloading arXiv metadata failed: #{ page.statusCode }", page.content
    else if page.error
      console.error page.error
      throw page.error

    page = blocking(xml2js.parseString) page.content

    count = 0

    for recordEntry in page['OAI-PMH'].ListRecords[0].record
      record = recordEntry.metadata?[0].arXivRaw?[0]

      if not record?
        # Using inspect because records can be heavily nested
        console.warn "Empty record metadata, skipping", util.inspect recordEntry, false, null
        continue

      # TODO: Really process versions
      created = moment.utc(record.version[0].date[0]).toDate()
      updated = moment.utc(record.version[record.version.length - 1].date[0]).toDate()

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
        [foreNames, lastName] = author.split /\s*([^\s.]+.?)\s*$/

        bad |= not foreNames or not lastName

        # Are there still escaped characters?
        bad |= /[\\{}]/.test(foreNames) or /[\\{}]/.test(lastName)

        foreNames: foreNames
        lastName: lastName

      if bad
        # Using inspect because records can be heavily nested
        console.warn "Could not parse authors, skipping", authors, util.inspect record, false, null
        continue

      # Remove collaboration information
      # Examples:
      #   Author One, Author Two, for the ABCD Collaboration
      #   ABCD Collaboration: Author One, Author Two, Author Three
      #   C.Sfienti, M. De Napoli, S. Bianchin, A.S. Botvina, J. Brzychczyk, A. Le Fevre, J. Lukasik, P. Pawlowski, W. Trautmann and the ALADiN2000 Collaboration
      authors = (author for author in authors when not (/collaboration/i.test(author.foreNames) or /collaboration/i.test(author.lastName)))

      if authors.length == 0
        # Using inspect because records can be heavily nested
        console.warn "Empty authors list, skipping", util.inspect record, false, null
        continue

      publication =
        created: created
        updated: updated
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
      if Publications.find({source: publication.source, foreignId: publication.foreignId}, limit: 1).count() == 0
        id = Publications.insert publication
        console.log "Added #{ publication.source }/#{ publication.foreignId } as #{ id }"
        count++

    console.log "Done"

    Meteor.call 'sync-local-pdf-cache' if count > 0

  'sync-local-pdf-cache': ->
    @unblock()

    console.log "Syncing local PDF cache"

    count = 0

    Publications.find(cached: {$ne: true}).forEach (publication) ->
      try
        publication.checkCache()
        count++ if publication.cached
      catch error
        console.error "#{ error }"

    console.log "Done"

    Meteor.call 'process-pdfs' if count > 0

  'process-pdfs': ->
    @unblock()

    console.log "Processing pending PDFs"

    Publications.find(cached: true, processed: {$ne: true}).forEach (publication) ->
      try
        publication.process()
      catch error
        console.error error

    console.log "Done"

  'dummy-comments': ->
    @unblock()

    console.log "Generating dummy comments"

    Publications.find(cached: true, processed: true, paragraphs: null).forEach (publication) ->
      publication.paragraphs = (page: 1, left: 0, top: 50 * i, width: 100, height: 50 for i in [0..Random.fraction() * 10 + 10])
      Publications.update publication._id, $set: paragraphs: publication.paragraphs

      for paragraph in [0...publication.paragraphs.length]
        comments = []
        for comment in [0...Random.fraction() * 20]
          comments.push(Comments.insert
            created: randomTimestamp()
            author: randomUser()
            body: dimsum(1 + Random.fraction() * 2).replace /\r/g, '' # There are some \r between paragraphs
            # 10 % of comments are top-level
            parent: if Random.fraction() < 0.1 then null else Random.choice comments
            publication: publication._id
            paragraph: paragraph
          )

      return # So that for loop does not return anything

    console.log "Done"

  'dummy-notes': ->
    @unblock()

    console.log "Generating dummy notes"

    Publications.find(cached: true, processed: true, paragraphs: $ne: null).forEach (publication) ->
      for paragraph in [0...publication.paragraphs.length]
        Notes.insert
          created: randomTimestamp()
          author: randomUser()
          body: dimsum(1 + Random.fraction() * 3).replace /\r/g, '' # There are some \ between paragraphs
          publication: publication._id
          paragraph: paragraph

      return # So that for loop does not return anything

    console.log "Done"
