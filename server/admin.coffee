class @ArXivPDF extends ArXivPDF
  @Meta
    name: 'ArXivPDF'
    replaceParent: true

  # A set of fields which are public and can be published to the client
  @PUBLISH_FIELDS: ->
    fields: {} # All, only admins have access

randomTimestamp = ->
  moment.utc().subtract('hours', Random.fraction() * 24 * 100).toDate()

updateBlogCache = @updateBlogCache

Meteor.methods
  'sample-data': methodWrap ->
    # If @connection is not set this means method is called from the server (eg., from auto installation)
    throw new Meteor.Error 403, "Permission denied." unless Meteor.person()?.isAdmin or not @connection

    @unblock()

    Meteor.call 'sync-arxiv-metadata'
    Meteor.call 'sync-local-pdf-cache'

  'test-job': methodWrap ->
    throw new Meteor.Error 403, "Permission denied." unless Meteor.person()?.isAdmin

    new TestJob({foo: 'bar'}).enqueue()

  'process-pdfs': methodWrap ->
    throw new Meteor.Error 403, "Permission denied." unless Meteor.person()?.isAdmin

    # To force reprocessing, we first set processError to true everywhere to assure there will be
    # change afterwards when we unset it. We set to true so that value is still true and processing
    # is not already triggered (but only when we unset the field).
    Publication.documents.update
      processed:
        $exists: false
    ,
      $set:
        processError: true
    ,
      multi: true
    Publication.documents.update
      processed:
        $exists: false
      processError: true
    ,
      $unset:
        processError: ''
    ,
      multi: true

  'reprocess-pdfs': methodWrap ->
    throw new Meteor.Error 403, "Permission denied." unless Meteor.person()?.isAdmin

    # To force reprocessing, we first set processError to true everywhere to assure there will be
    # change afterwards when we unset it. We set to true so that value is still true and processing
    # is not already triggered (but only when we unset the field).
    Publication.documents.update {},
      $set:
        processError: true
    ,
      multi: true
    Publication.documents.update {},
      $unset:
        processed: ''
        processError: ''
    ,
      multi: true

  'database-update-all': methodWrap ->
    throw new Meteor.Error 403, "Permission denied." unless Meteor.person()?.isAdmin

    Document.updateAll()

  'sync-arxiv-pdf-cache': methodWrap ->
    throw new Meteor.Error 403, "Permission denied." unless Meteor.person()?.isAdmin

    @unblock()

    if not Meteor.settings.AWS
      Log.error "AWS settings missing"
      throw new Meteor.Error 500, "AWS settings missing."

    Log.info "Syncing arXiv PDF cache"

    s3 = new AWS.S3()

    list = blocking(s3, s3.listObjects)
      Bucket: 'arxiv'
      Prefix: 'pdf/'
      RequestPayer: 'requester'

    for file in list.Contents
      if not /\.tar$/.test file.Key
        continue

      lastModified = moment.utc file.LastModified

      fileObj =
        key: file.Key
        lastModified: lastModified.toDate()
        eTag: file.ETag.replace /^"|"$/g, '' # It has " at the start and the end
        size: file.Size

      if ArXivPDF.documents.find(fileObj, limit: 1).count() != 0
        continue

      processPDF = (fun, props, pdf) ->
        match = ARXIV_OLD_ID_REGEX.exec props.path
        if match
          id = match[1] + '/' + match[2]
        else
          match = ARXIV_NEW_ID_REGEX.exec props.path
          if match
            id = match[1]
          else
            Log.error "Invalid filename #{ props.path }"
            throw new Meteor.Error 500, "Invalid filename '#{ props.path }'."

        ArXivPDF.documents.update fileObj._id,
          $addToSet:
            PDFs:
              id: id
              path: props.path
              size: props.size
              mtime: moment.utc(props.mtime).toDate()
        fun id, pdf

      finishPDF = ->
        ArXivPDF.documents.update fileObj._id, $set: processingEnd: moment.utc().toDate()

      Meteor.bindEnvironment processPDF, ((error) -> throw error), @
      Meteor.bindEnvironment finishPDF, ((error) -> throw error), @

      processTar = blocking (key, fun, cb) ->
        finished = false
        counter = 0

        finalCallback = ->
          finishPDF()
          cb null

        processPDFWrapped = (fun, props, pdf) ->
          counter++
          processPDF fun, props, pdf
          counter--
          if finished and counter == 0
            finalCallback()

        Log.info "Processing tar: #{ key }"

        fileObj.processingStart = moment.utc().toDate()
        fileObj._id = ArXivPDF.documents.insert fileObj

        s3.getObject(
          Bucket: 'arxiv'
          Key: key
          RequestPayer: 'requester'
        ).createReadStream().pipe(
          tar.Parse()
        ).on('ignoredEntry', (entry) ->
          Log.error "Ignored entry in #{ key } tar file: #{ entry.props }"
        ).on('entry', (entry) ->
          if entry.props.type != tar.types.File
            return

          buffer = new Buffer entry.props.size
          offset = 0

          entry.on 'data', (chunk) ->
            chunk.copy buffer, offset
            offset += chunk.length
          entry.on 'end', ->
            assert.equal offset, entry.props.size, "#{ offset }, #{ entry.props.size }"
            processPDFWrapped fun, entry.props, buffer

        ).on('end', ->
          finished = true
          if counter == 0
            finalCallback()
        )

      processTar file.Key, (id, pdf) ->
        Log.info "Storing PDF: #{ id }"

        Storage.save (Publication._filenamePrefix() + Publication._arXivFilename(id)), pdf

    Log.info "Done"

  'sync-arxiv-metadata': methodWrap ->
    # If @connection is not set this means method is called from the server (eg., from auto installation)
    throw new Meteor.Error 403, "Permission denied." unless Meteor.person()?.isAdmin or not @connection

    new ArXivMetadataJob().enqueue()

  'sync-local-pdf-cache': methodWrap ->
    # If @connection is not set this means method is called from the server (eg., from auto installation)
    throw new Meteor.Error 403, "Permission denied." unless Meteor.person()?.isAdmin or not @connection

    new CacheSyncJob().enqueue()

  'sync-fsm-metadata': methodWrap ->
    throw new Meteor.Error 403, "Permission denied." unless Meteor.person()?.isAdmin

    new FSMMetadataJob().enqueue()

  'sync-blog': methodWrap ->
    throw new Meteor.Error 403, "Permission denied." unless Meteor.person()?.isAdmin

    new TumblrJob().enqueue
      delay: 0

Meteor.publish 'arxiv-pdfs', ->
  return unless @personId

  @related (person) ->
    return unless person?.isAdmin

    ArXivPDF.documents.find {},
      fields: ArXivPDF.PUBLISH_FIELDS().fields
      sort: [
        ['processingStart', 'desc']
      ]
      limit: 5
  ,
    Person.documents.find
      _id: @personId
    ,
      fields:
        # _id field is implicitly added
        isAdmin: 1
