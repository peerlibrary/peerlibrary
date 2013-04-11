do -> # To not pollute the namespace
  if Meteor.settings.AWS
    AWS.config.update
      accessKeyId: Meteor.settings.AWS.accessKeyId
      secretAccessKey: Meteor.settings.AWS.secretAccessKey
  else
    console.warn "AWS settings missing, arXiv PDF processing will not work"

  # It seems there are no subject classes
  ARXIV_OLD_ID_REGEX = /(?:\/|\\)([a-z-]+)(\d+)\.pdf$/i

  # It seems there are no versions in PDFs
  ARXIV_NEW_ID_REGEX = /(?:\/|\\)([\d.]+)\.pdf$/i

  Meteor.methods
    'refresh-arxhiv-pdfs': ->
      console.log "Refreshing arXiv PDFs"

      s3 = new AWS.S3()

      list = blocking s3, s3.listObjects
        Bucket: 'arxiv'
        Prefix: 'pdf/'
        RequestPayer: 'requester'

      for file in list.Contents
        lastModified = moment.utc file.LastModified

        fileObj =
          key: file.Key
          lastModified: lastModified.toDate()
          eTag: file.ETag.replace /"/g, '' # It has " at the start and the end
          size: file.Size

        if ArXivPDFs.find(fileObj).count() != 0
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
              throw new Error "Invalid filename #{ props.path }"

          ArXivPDFs.update fileObj._id,
            $addToSet:
              PDFs:
                id: id
                path: props.path
                size: props.size
                mtime: moment.utc(props.mtime).toDate()
          fun id, pdf

        processTar = blocking (key, fun, cb) ->
          finished = false
          counter = 0

          finalCallback = ->
            ArXivPDFs.update fileObj._id,
              $set:
                processingEnd: moment.utc().toDate()
            cb null

          processPDFWrapped = (args) ->
            [fun, props, pdf] = args
            counter++
            processPDF fun, props, pdf
            counter--
            if finished and counter == 0
              finalCallback()

          console.log "Processing tar: #{ key }"

          fileObj.processingStart = moment.utc().toDate()
          fileObj._id = ArXivPDFs.insert fileObj

          s3.getObject(
            Bucket: 'arxiv'
            Key: key
            RequestPayer: 'requester'
          ).createReadStream().pipe(
            tar.Parse()
          ).on('ignoredEntry', (entry) ->
            console.error "Ignored entry in #{ key } tar file", entry.props
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
              # At this point it seems we are not in the Fiber anymore, but we have to be
              blocking.Fiber(processPDFWrapped).run([fun, entry.props, buffer])

          ).on('end', ->
            finished = true
            if counter == 0
              blocking.Fiber(finalCallback).run()
          )

        processTar file.Key, (id, pdf) ->
          console.log "Processing PDF: #{ id }"

          Storage.save 'arxiv' + Storage._path.sep + id + '.pdf', pdf

      console.log "Done"
