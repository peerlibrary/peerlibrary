class Publication extends Publication
  download: =>
    # TODO: Replace with @url()
    result = Meteor.http.get 'https://github.com/mozilla/pdf.js/raw/master/web/compressed.tracemonkey-pldi-09.pdf',
      timeout: 10000 # ms
      encoding: null # PDFs are binary data

    if result.error
      throw result.error
    else if result.statusCode != 200
      throw new Meteor.Error 500, "Downloading failed"

    # TODO: This kills fiber after some time so whole PeerLibrary is restarted
    Storage.save @filename(), result.content

    @downloaded = true
    Publications.update @_id, $set: downloaded: @downloaded

    result.content

  process: (pdfFile, progressCallback) =>
    pdfFile ?= Storage.open @filename()
    progressCallback ?= ->
    PDF.process pdfFile, progressCallback

    @processed = true
    Publications.update @_id, $set: processed: @processed

do -> # To not pollute the namespace
  Meteor.publish 'publications-by', (username) ->
    Publications.find
      owner: username
    ,
      fields:
        created: 1
        updated: 1
        authors: 1
        title: 1
        comments: 1
        abstract: 1
        doi: 1
        foreignId: 1
        source: 1
