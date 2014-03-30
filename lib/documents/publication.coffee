class @Publication extends AccessDocument
  # access: 0 (private), 1 (closed), 2 (open)
  # readPersons: if private access, list of persons who have read permissions
  # readGroups: if private access, list of groups who have read permissions
  # createdAt: timestamp when the publication was published (we match PeerLibrary document creation date with publication publish date)
  # updatedAt: timestamp when the publication (or its metadata) was last updated
  # slug: slug for URL
  # authors: list of
  #   _id: author's person id
  #   slug: author's person id
  #   givenName
  #   familyName
  # authorsRaw: unparsed authors string
  # title
  # comments: comments about the publication, a free-form text, metadata provided by the source
  # abstract
  # hasAbstract (client only): boolean if document has an abstract, used only in search results (cheaper to send than the whole abstract)
  # doi
  # msc2010: list of MSC 2010 classes
  # acm1998: list of ACM 1998 classes
  # foreignId: id of the publication used by the source
  # foreignCategories: categories metadata provided by the source
  # foreignJournalReference: journal reference metadata provided by the source
  # source: a string identifying where was this publication fetched from
  # sha256: SHA-256 hash of the file
  # size: size of the file (if cached)
  # importing: (temporary) list of
  #   person: person importing the document
  #   filename: original name of the imported file
  #   temporaryFilename: temporary filename of the imported file
  # cached: timestamp when the publication was cached
  # metadata: do we have metadata?
  # processed: timestamp when the publication was processed (file checked, text extracted, thumbnails generated, etc.)
  # processError:
  #   error: description of the publication processing error
  #   stack: stack trace of the error
  # numberOfPages
  # fullText: full plain text content suitable for searching
  # annotations: list of (reverse field from Annotation.publication)
  #   _id: annotation id
  # searchResult (client only): the last search query this publication is a result for, if any, used only in search results
  #   _id: id of the query, an _id of the SearchResult object for the query
  #   order: order of the result in the search query, lower number means higher

  @Meta
    name: 'Publication'
    fields: =>
      authors: [@ReferenceField Person, ['slug', 'givenName', 'familyName', 'user.username']]
      importing: [
        person: @ReferenceField Person
      ]
      slug: @GeneratedField 'self', ['title']
      fullText: @GeneratedField 'self', ['cached', 'processed', 'processError', 'importing', 'source', 'foreignId']

  @_filenamePrefix: ->
    'pdf' + Storage._path.sep

  @_importFilename: (id) ->
    'import' + Storage._path.sep + id + '.pdf'

  @_arXivFilename: (arXivId) ->
    'arxiv' + Storage._path.sep + arXivId + '.pdf'

  filename: =>
    Publication._filenamePrefix() + switch @source
      when 'import' then Publication._importFilename @_id
      when 'arXiv' then Publication._arXivFilename @foreignId
      else throw new Error "Unsupported source"

  url: =>
    Storage.url @filename()

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

  hasReadAccess: (person) =>
    return false unless @cached

    return true if person?.isAdmin

    return true if @_id in _.pluck person?.library, '_id'

    return false unless @processed

    return true if @access is Publication.ACCESS.OPEN

    return true if @access is Publication.ACCESS.CLOSED

    # Access should be private here, if it is not, we prevent access to the document
    # TODO: Should we log this?
    return false unless @access is Publication.ACCESS.PRIVATE

    return false unless person?._id

    return true if person._id in _.pluck @readPersons, '_id'

    personGroups = _.pluck person?.inGroups, '_id'
    publicationGroups = _.pluck @readGroups, '_id'

    return true if _.intersection(personGroups, publicationGroups).length

    return false

  @requireReadAccessSelector: (person, selector) ->
    # We use $and to not override any existing selector field
    selector.$and = [] unless selector.$and
    selector.$and.push
      cached:
        $exists: true

    return selector if person?.isAdmin

    selector.$and.push
      $or: [
        processed:
          $exists: true
        $or: [
          access: Publication.ACCESS.OPEN
        ,
          access: Publication.ACCESS.CLOSED
        ,
          access: Publication.ACCESS.PRIVATE
          'readPersons._id': person?._id
        ,
          access: Publication.ACCESS.PRIVATE
          'readGroups._id':
            $in: _.pluck person?.inGroups, '_id'
        ]
      ,
        _id:
          $in: _.pluck person?.library, '_id'
      ]
    selector

  @defaultAccess: ->
    @ACCESS.OPEN
