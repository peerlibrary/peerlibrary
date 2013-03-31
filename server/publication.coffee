class Publication extends Document
  url: =>
    Storage.url @filename()

  filename: =>
    @_id + '.pdf'

  download: =>
    result = Meteor.http.get @originalUrl,
      timeout: 10000 # ms
      encoding: null # PDFs are binary data

    if result.error
      throw result.error
    else if result.statusCode != 200
      throw new Meteor.Error 500, "Downloading failed"

    Storage.save @filename(), result.content

    @downloaded = true
    Publications.update @_id, $set: downloaded: @downloaded

    result.content

  process: (pdfFile, progressCallback) =>
    pdfFile ?= Storage.open @filename()
    PDF.process pdfFile, progressCallback

    @processed = true
    Publications.update @_id, $set: processed: @processed

do -> # To not pollute the namespace
  Meteor.publish 'publications', ->
    Publications.find()
  Meteor.publish 'publications-by', (username) ->
    Publications.find
      owner: username
    ,
      fields:
        title: 1
        owner: 1
        authors: 1
        score: 1
        pubDate: 1
        field: 1
        topics: 1
        bookmarkCount: 1
        commentCount: 1
        abstract: 1

  Meteor.publish 'get-publication', (publicationId) ->
    uuid = Meteor.uuid()

    @added 'get-publication', uuid, {status: "Opening publication"}
    @ready()

    publication = Publications.findOne publicationId

    if !publication?
      throw new Meteor.Error 404, "Publication not found"

    if !publication.downloaded
      @changed 'get-publication', uuid, {status: "Downloading publication"}

      # TODO: Can we somehow display progress to the user?
      pdfFile = publication.download()

    setProgress = false

    if !publication.processed
      @changed 'get-publication', uuid, {status: "Processing publication"}

      publication.process pdfFile, (progress) =>
        @changed 'get-publication', uuid, {progress: progress}
        setProgress = true

    final =
      status: "Displaying publication"
      url: publication.url()

    if setProgress
      # We clear the progress
      final.progress = undefined

    @changed 'get-publication', uuid, final

    return # So that we do not return any results
