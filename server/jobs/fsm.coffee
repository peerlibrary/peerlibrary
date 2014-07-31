HTTP_TIMEOUT = 60000 # ms

unless Meteor.settings?.FSM?.appId and Meteor.settings?.FSM?.appKey
  Log.warn "FSM settings missing, syncing FSM archive will not work"

class @FSMMetadataJob extends Job
  constructor: (data) ->
    super

    # We throw a fatal error to stop retrying a job if settings are not
    # available anymore, but they were in the past when job was added
    throw new Job.FatalJobError "FSM settings missing" unless Meteor.settings?.FSM?.appId and Meteor.settings?.FSM?.appKey

  run: =>
    page = HTTP.get "https://apis.berkeley.edu/solr/fsm/select?q=-fsmImageUrl:*&wt=json&indent=on&rows=1000&app_id=#{ Meteor.settings.FSM.appId }&app_key=#{ Meteor.settings.FSM.appKey }",
      timeout: HTTP_TIMEOUT

    # TODO: Implement pagination
    assert page.data.response.docs.length, page.data.response.numFound

    count = 0

    for document in page.data.response.docs
      dateCreated = document.fsmDateCreated?[0]

      if dateCreated
        # Some dates are wrapped in [], or contain [] around months, remove all that
        dateCreated = dateCreated.replace /\[|\]/g, ''

      createdAt = moment.utc dateCreated

      unless createdAt.isValid()
        # Using inspect because documents can be heavily nested
        # TODO: What to do in this case?
        @log "Could not parse created date, setting to current date '#{ dateCreated }', #{ util.inspect document, false, null }",
          level: 'warning'
        createdAt = moment.utc()

      createdAt = createdAt.toDate()
      updatedAt = createdAt

      # Normalizing whitespace
      authors = document.fsmCreator?[0].replace(/\s+/g, ' ') or ''

      # To clean nested parentheses
      while true
        authorsCleaned = authors.replace /\([^()]*?\)/g, '' # For now, remove all comments/notes
        if authorsCleaned == authors
          break
        else
          authors = authorsCleaned

      # We split at : too, so that staff information is seen as a separate author (see examples below)
      authors = for author in authors.split /^\s*|\s*[;:]\s*|\s*$/i when author and not /^(staff|et al|chairman|emergency executive committee|prepared by a fact-finding committee of graduate political scientists|berkeley division of the academic senate)$/i.test author
        segments = (segment for segment in author.split /,\s*/ when segment)

        continue unless segments.length

        if segments.length > 1
          segments = (segment for segment in segments when not /committee/i.test segment)

        # Names with spaces in-between instead of commas
        if segments.length is 1 and /Truman|Letewka|Muscatine|Schachman|Searle|Sellers|Selznick|Stampp|Broek|Wolin|Zelnik|Douglas|Leonard|Iiyama|Mellin|Novick|Weinberg|Weller|Bressler|Cheit|Schorske|Sherry|Williams|Jennings|Ross/.test segments[0]
          segments = segments[0].split /\s+/
          segments = [segments[segments.length - 1], segments[0..segments.length - 2].join ' ']

        if segments.length is 1
          if segments[0] is "Lawyer's Committee"
            # Fixing discrepancy
            givenName: "Lawyers' Committee"
          else
            givenName: segments[0]
        else if segments.length is 2
          if /SLATE/.test segments[1]
            # Fixing special case
            givenName: 'SLATE'
          else if /Certain Faculty Members/.test segments[0]
            # Fixing special case
            givenName: 'Certain Faculty Members of the University of California, Berkeley'
          else if /Congress of Racial Equality/.test segments[0]
            # Fixing special case
            givenName: 'Congress of Racial Equality, Berkeley Campus Chapter'
          else if segments[1] is 'Inc.'
            givenName: "#{ segments[0] }, #{ segments[1] }"
          else
            givenName: segments[1]
            familyName: segments[0]
        else if segments[2] is 'Jr.'
          givenName: "#{ segments[1] } #{ segments[2] }"
          familyName: segments[0]
        else
          # Otherwise we simply ignore the rest (affiliation, birth dates, etc.)
          givenName: segments[1]
          familyName: segments[0]

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
        title: document.fsmTitle[0]
        foreignId: document.id
        foreignUrl: document.fsmTeiUrl[0]
        # TODO: Put foreign categories into tags?
        foreignCategories: document.fsmTypeOfResource
        source: 'FSM'
        license: 'https://creativecommons.org/licenses/by-nc-sa/3.0/us/'
        cachedId: Random.id()
        mediaType: 'tei'

      if document.fsmDateCreated?[0]
        publication.createdRaw = document.fsmDateCreated[0]

      if document.fsmCreator?[0]
        publication.authorsRaw = document.fsmCreator[0]

      if document.fsmRelatedTitle?.length
        publication.comments = document.fsmRelatedTitle.join '\n'

      # TODO: Use findAndModify
      if Publication.documents.find({source: publication.source, foreignId: publication.foreignId}, limit: 1).count() == 0
        id = Publication.documents.insert Publication.applyDefaultAccess null, publication
        @log "Added #{ publication.source }/#{ publication.foreignId } as #{ id }"
        count++

    count: count

Job.addJobClass FSMMetadataJob

class @FSMCacheJob extends Job
  run: =>
    count = 0

    Publication.documents.find(source: 'FSM', cached: {$exists: false}).forEach (publication) =>
      if not Storage.exists publication.cachedFilename()
        @log "Caching file for #{ publication._id }: #{ publication.foreignFilename() } -> #{ publication.cachedFilename() }"

        tei = HTTP.get publication.foreignUrl,
          timeout: 10000 # ms
          encoding: null # PDFs are binary data

        Storage.save publication.foreignFilename(), tei.content
        assert Storage.exists publication.foreignFilename()
        Storage.link publication.foreignFilename(), publication.cachedFilename()
        assert Storage.exists publication.cachedFilename()

      if not publication.sha256
        pdfContent = Storage.open publication.cachedFilename()
        hash = new Crypto.SHA256()
        hash.update pdfContent
        publication.sha256 = hash.finalize()

      publication.cached = moment.utc().toDate()
      Publication.documents.update publication._id,
        $set:
          cached: publication.cached
          sha256: publication.sha256

      count++

    count: count

Job.addJobClass FSMCacheJob
