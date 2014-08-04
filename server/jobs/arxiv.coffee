HTTP_TIMEOUT = 60000 # ms

if Meteor.settings?.AWS?.accessKeyId and Meteor.settings?.AWS?.secretAccessKey
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

class @ArXivMetadataJob extends Job
  enqueueOptions: (options) =>
    options = super

    _.defaults options,
      priority: 'medium'

  run: =>
    # TODO: URL hardcoded - not good
    # TODO: Implement pagination
    # TODO: Store last fetch timestamp

    page = HTTP.get 'http://export.arxiv.org/oai2?verb=ListRecords&from=2007-05-23&until=2007-05-24&metadataPrefix=arXivRaw',
      timeout: HTTP_TIMEOUT

    page = xml2js.parseStringSync page.content

    thisJob = @getQueueJob()
    count = 0

    for recordEntry in page['OAI-PMH'].ListRecords[0].record
      record = recordEntry.metadata?[0].arXivRaw?[0]

      if not record?
        # TODO: Replace inspect with log payload
        @logWarn "Empty record metadata, skipping #{ util.inspect recordEntry, false, null }"
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
        # TODO: Replace inspect with log payload
        @logWarn "Could not parse authors, skipping #{ authors }, #{ util.inspect record, false, null }"
        continue

      # Remove collaboration information
      # Examples:
      #   Author One, Author Two, for the ABCD Collaboration
      #   ABCD Collaboration: Author One, Author Two, Author Three
      #   C.Sfienti, M. De Napoli, S. Bianchin, A.S. Botvina, J. Brzychczyk, A. Le Fevre, J. Lukasik, P. Pawlowski, W. Trautmann and the ALADiN2000 Collaboration
      authors = (author for author in authors when not (/collaboration/i.test(author.givenName) or /collaboration/i.test(author.familyName)))

      if authors.length == 0
        # TODO: Replace inspect with log payload
        @logWarn "Empty authors list, skipping #{ util.inspect record, false, null }"
        continue

      authors = for author in authors
        # TODO: Use findAndModify
        existingAuthor = Person.documents.findOne
          givenName: author.givenName
          familyName: author.familyName
        ,
          fields:
            # _id field is implicitly added
            givenName: 1
            familyName: 1
        if existingAuthor
          existingAuthor
        else
          authorCreatedAt = moment.utc().toDate()
          author._id = Random.id()
          Person.documents.insert Person.applyDefaultAccess null, _.extend author,
            slug: author._id # We set it manually to prevent two documents having temporary null value which is invalid and throws a duplicate key error
            user: null
            publications: []
            createdAt: authorCreatedAt
            updatedAt: authorCreatedAt
          author

      publication =
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
        license: record.license?[0] or 'arXiv'
        cachedId: Random.id()
        mediaType: 'pdf'

      # TODO: Deal with this
      #if publication.msc2010?
      # We check if we really converted without "(primary)" and similar strings
      #assert.equal (cls for cls in publication.msc2010 when cls.match(/[()]/)).length, 0, "#{ publication.foreignId }: #{ publication.msc2010 }"

      # TODO: Use findAndModify
      if not Publication.documents.exists(source: publication.source, foreignId: publication.foreignId)
        id = Publication.documents.insert Publication.applyDefaultAccess null, publication
        @logInfo "Added #{ publication.source }/#{ publication.foreignId } as #{ id }"
        count++ if new CheckCacheJob(publication: _.pick publication, '_id').enqueue(
          skipIfExisting: true
          depends: thisJob # To create a relation
        )

    count: count

Job.addJobClass ArXivMetadataJob
