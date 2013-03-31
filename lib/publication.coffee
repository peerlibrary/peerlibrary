Publications = new Meteor.Collection 'publications', transform: (doc) -> new Publication doc

class Publication extends Document
  filename: =>
    @_id + '.pdf'

  url: =>
    if @downloaded
      return Storage.url @filename()

    switch @source
      when 'arXiv' then "http://arxiv.org/pdf/#{ @foreignId }"
      else assert false, @source
