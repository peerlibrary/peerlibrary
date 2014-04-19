class @Publication extends AccessDocument
  # access: 0 (private, Publication.ACCESS.PRIVATE), 1 (closed, Publication.ACCESS.CLOSED), 2 (open, Publication.ACCESS.OPEN)
  # readPersons: if private access, list of persons who have read permissions
  # readGroups: if private access, list of groups who have read permissions
  # createdAt: timestamp when the publication was published (we match PeerLibrary document creation date with publication publish date)
  # createdRaw: unparsed created string
  # updatedAt: timestamp when the publication (or its metadata) was last updated
  # slug: slug for URL
  # authors: list of
  #   _id: author's person id
  #   slug: author's person id
  #   givenName
  #   familyName
  #   user
  #     username
  # authorsRaw: unparsed authors string
  # title
  # comments: comments about the publication, a free-form text, metadata provided by the source
  # abstract
  # hasAbstract (client only): boolean if document has an abstract, used only in search results (cheaper to send than the whole abstract)
  # doi
  # msc2010: list of MSC 2010 classes
  # acm1998: list of ACM 1998 classes
  # foreignId: id of the publication used by the source
  # foreignUrl: URL of a foreign content file (to cache)
  # foreignCategories: categories metadata provided by the source
  # foreignJournalReference: journal reference metadata provided by the source
  # source: a string identifying where was this publication fetched from
  # sha256: SHA-256 hash of the file
  # size: size of the file (if cached)
  # importing: (temporary) list of
  #   person: person importing the document
  #   filename: original name of the imported file
  #   importingId: used for the temporary filename of the importing file
  # cached: timestamp when the publication was cached
  # cachedId: used for the the cached filename (availble for open access publications, if user has the publication in the library, or is a private publication)
  # mediaType: which media type a cached file is (currently supported: pdf, tei)
  # metadata: do we have metadata?
  # processed: timestamp when the publication was processed (file checked, text extracted, thumbnails generated, etc.)
  # processError:
  #   error: description of the publication processing error
  #   stack: stack trace of the error
  # numberOfPages
  # fullText: full plain text content suitable for searching
  # annotations: list of (reverse field from Annotation.publication)
  #   _id: annotation id
  # referencingAnnotations: list of (reverse field from Annotation.references.publications)
  #   _id: annotation id
  # license: license information, if known
  # searchResult (client only): the last search query this document is a result for, if any, used only in search results
  #   _id: id of the query, an _id of the SearchResult object for the query
  #   order: order of the result in the search query, lower number means higher

  @Meta
    name: 'Publication'
    fields: =>
      authors: [@ReferenceField Person, ['slug', 'givenName', 'familyName', 'user.username'], true, 'publications']
      importing: [
        person: @ReferenceField Person
      ]
      slug: @GeneratedField 'self', ['title']
      fullText: @GeneratedField 'self', ['cached', 'cachedId', 'mediaType', 'processed', 'processError']

  @_filenamePrefix: ->
    'publication' + Storage._path.sep

  cachedFilename: =>
    throw new Error "Cached filename not available" unless @cachedId and @mediaType

    Publication._filenamePrefix() + 'cache' + Storage._path.sep + @cachedId + '.' + @mediaType

  url: =>
    Storage.url @cachedFilename()

  thumbnail: (page) =>
    if page < 1 or page > @numberOfPages
      throw new Error "Page out of bounds: #{ page }/#{ @numberOfPages }"

    'thumbnail' + Storage._path.sep + @_id + Storage._path.sep + page + '-125x95.png'

  thumbnailUrl: (page) =>
    thumbnail = new String Storage.url @thumbnail page
    thumbnail.page = page
    thumbnail

  thumbnailUrls: =>
    @thumbnailUrl page for page in [1..@numberOfPages]

  createdDay: =>
    moment(@createdAt).format 'MMMM Do YYYY'

  @ACCESS:
    PRIVATE: ACCESS.PRIVATE
    CLOSED: 1
    OPEN: 2

  hasReadAccess: (person, cache=false) =>
    return false unless @cached

    return true if person?.isAdmin

    return true if @_id in _.pluck person?.library, '_id'

    return false unless @processed

    return true if @access is Publication.ACCESS.OPEN

    return not cache if @access is Publication.ACCESS.CLOSED

    # Access should be private here, if it is not, we prevent access to the document
    # TODO: Should we log this?
    return false unless @access is Publication.ACCESS.PRIVATE

    return false unless person?._id

    return true if person._id in _.pluck @readPersons, '_id'

    personGroups = _.pluck person?.inGroups, '_id'
    publicationGroups = _.pluck @readGroups, '_id'

    return true if _.intersection(personGroups, publicationGroups).length

    return false

  hasCacheAccess: (person) =>
    @hasReadAccess person, true

  @requireReadAccessSelector: (person, selector, cache=false) ->
    # To not modify input
    selector = EJSON.clone selector

    # We use $and to not override any existing selector field
    selector.$and = [] unless selector.$and
    selector.$and.push
      cached:
        $exists: true

    return selector if person?.isAdmin

    accessConditions = [
      access: Publication.ACCESS.OPEN
    ,
      access: Publication.ACCESS.PRIVATE
      'readPersons._id': person?._id
    ,
      access: Publication.ACCESS.PRIVATE
      'readGroups._id':
        $in: _.pluck person?.inGroups, '_id'
    ]

    unless cache
      # Access to publication metadata is allowed for closed access
      # publications, only access to cache information is not
      accessConditions.push
        access: Publication.ACCESS.CLOSED

    selector.$and.push
      $or: [
        processed:
          $exists: true
        $or: accessConditions
      ,
        _id:
          $in: _.pluck person?.library, '_id'
      ]
    selector

  @requireCacheAccessSelector: (person, selector) ->
    @requireReadAccessSelector person, selector, true

  @defaultAccess: ->
    @ACCESS.OPEN
