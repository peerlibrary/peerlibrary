@Publications = new Meteor.Collection 'Publications', transform: (doc) => new @Publication doc

class @Publication extends Document
  # slug: slug for URL
  # created: timestamp when the publication was published
  # updated: timestamp when the publication (or its metadata) was last updated
  # authors: list of
  #   _id: author's person id
  #   slug: author's person id
  #   foreNames
  #   lastName
  # authorsRaw: unparsed authors string
  # title
  # comments: comments about the publication, a free-form text, metadata provided by the source
  # abstract
  # doi
  # msc2010: list of MSC 2010 classes
  # acm1998: list of ACM 1998 classes
  # foreignId: id of the publication used by the source
  # foreignCategories: categories metadata provided by the source
  # foreignJournalReference: journal reference metadata provided by the source
  # source: a string identifying where was this publication fetched from
  # sha256: SHA-256 hash of the file
  # size: size of the file (if cached)
  # importing (temporary):
  #   by: list of
  #     person: person importing the document
  #     filename: original name of the uploaded file
  #     temporary: temporary id of the uploaded file
  #     uploadProgress: 0-1, progress of uploading (%)
  # cached: do we have a locally stored PDF?
  # metadata: do we have metadata?
  # processed: has PDF been processed (file checked, text extracted, thumbnails generated, etc.)
  # numberOfPages
  # searchResult (client only): the last search query this publication is a result for, if any
  #   _id: id of the query, an _id of the SearchResult object for the query
  #   order: order of the result in the search query, lower number means higher

  # Should be a function so that we can possible resolve circual references
  @Meta =>
    collection: Publications
    fields:
      authors: [@ReferenceField Person, ['slug', 'foreNames', 'lastName']]
      importing:
        by: [
          person: @ReferenceField Person
        ]
      slug: @GeneratedField 'self', ['title']

  @_filenamePrefix: ->
    'pdf' + Storage._path.sep

  @_uploadFilename: (id) ->
    'upload' + Storage._path.sep + id + '.pdf'

  @_arXivFilename: (arXivId) ->
    'arxiv' + Storage._path.sep + arXivId + '.pdf'

  filename: =>
    Publication._filenamePrefix() + switch @source
      when 'upload' then Publication._uploadFilename @_id
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
    moment(@created).format 'MMMM Do YYYY'
