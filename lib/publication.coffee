Publications = new Meteor.Collection 'Publications', transform: (doc) -> new Publication doc

class Publication extends Document
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

  filename: =>
    @_id + '.pdf'

  url: =>
    console.warn "PDF #{ @_id } not cached" if not @cached
    Storage.url @filename()

  createdDay = =>
    moment(@created).format 'MMMM Do YYYY'