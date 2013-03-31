class Publication extends Publication
  download: =>
    result = Meteor.http.get @url(),
      timeout: 10000 # ms
      encoding: null # PDFs are binary data
      headers:
        # TODO: We set user agent so that arXiv allows us to download PDFs, but we should not misuse this and should switch to S3 for real thing
        # http://arxiv.org/help/bulk_data_s3, https://github.com/possibilities/meteor-awssum, http://awssum.io/amazon/s3/
        'User-Agent': 'Wget'

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

  @publicFields: ->
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

do -> # To not pollute the namespace
  Meteor.publish 'publications-by-owner', (username) ->
    Publications.find
      owner: username
    ,
      Publication.publicFields()

  Meteor.publish 'publications-by-id', (publicationId) ->
    Publications.find publicationId, Publication.publicFields()
