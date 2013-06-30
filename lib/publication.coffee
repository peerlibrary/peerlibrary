Publications = new Meteor.Collection 'Publications', transform: (doc) => new @Publication doc

class Publication extends @Document
  # created: timestamp when the publication was published
  # updated: timestamp when the publication (or its metadata) was last updated
  # authors: a list of authors, each author:
  #   lastName
  #   foreNames
  #   affiliation
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
  # cached: do we have a locally stored PDF?
  # processed: has PDF been processed (file checked, text extracted, parapraphs detected, etc.)
  # paragraphs: list of paragraphs of the publication, paragraphs are indexed by their position in list, zero-based
  #   page: one-based
  #   left: left coordinate
  #   top: top coordinate
  #   width: width of the paragraph
  #   height: height of the paragraph
  # numberOfPages
  # searchResult (client only): the last search query this publication is a result for, if any
  #   query: query object or string as provided by the client
  #   order: order of the result in the search query, lower number means higher

  @_filenamePrefix: ->
    'pdf' + Storage._path.sep

  @_arXivFilename: (arXivId) ->
    'arxiv' + Storage._path.sep + arXivId + '.pdf'

  filename: =>
    Publication._filenamePrefix() + switch @source
      when 'arXiv' then Publication._arXivFilename @foreignId
      else throw new Meteor.Error 500, "Unsupported source"

  url: =>
    Storage.url @filename()

  thumbnail: (page) =>
    if page < 1 or page > @numberOfPages
      throw new Meteor.Error 500, "Page out of bounds: #{ page }/#{ @numberOfPages }"

    'thumbnail' + Storage._path.sep + @_id + Storage._path.sep + page + '-125x95.png'

  thumbnailUrl: (page) =>
    Storage.url @thumbnail page

  thumbnailUrls: =>
    @thumbnailUrl page for page in [1..@numberOfPages]

  createdDay: =>
    moment(@created).format 'MMMM Do YYYY'

@Publications = Publications
@Publication = Publication
