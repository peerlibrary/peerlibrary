class @Publication extends Document
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
  # access: 0 (private), 1 (closed), 2 (open)
  # readUsers: if private access, list of users who have read permissions
  # readGroups: if private access, list of groups who have read permissions
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
      readUsers: [@ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username']]
      readGroups: [@ReferenceField Group, ['slug', 'name']]

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
    PRIVATE: 0
    CLOSED: 1
    OPEN: 2
