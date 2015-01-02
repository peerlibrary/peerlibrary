Meteor.methods
  'sample-data': methodWrap ->
    # If @connection is not set this means method is called from the server (eg., from auto installation)
    throw new Meteor.Error 403, "Permission denied." unless Meteor.person()?.isAdmin or not @connection

    # Currently, a sample is simply current smaller set of arXiv metadata
    # publications which then has cache synced with PDFs from the central server
    # TODO: Think how to make a better sample which would contain both metadata and content
    Meteor.call 'sync-arxiv-metadata'

  'ping-es': methodWrap ->
    throw new Meteor.Error 403, "Permission denied." unless Meteor.person()?.isAdmin
    # Publication.documents.find({}).forEach (publication, i, cursor) =>
    #   console.log publication._id, publication.title
    response = blocking(ES, ES.ping) { 
      requestTimeout: 1000,
      hello: "elasticsearch!"
    }

  'reset-es': methodWrap ->
    throw new Meteor.Error 403, "Permission denied." unless Meteor.person()?.isAdmin
    blocking(ES, ES.indices.delete) {
      index: '_all'
    }
    response = blocking(ES, ES.indices.create) {
      index: 'publication',
      body: {
        "mappings": {
          "publication" : {
            "properties" : {
              "fullText" : {
                "type" : "string",
                "analyzer": "english"
              },
              "title" : {
                "type" : "string",
                "analyzer": "english"
              }
            }
          }
        }
      }
    },
    (error, response) ->
      console.log "Response from ES(Creating Index): "
      console.log response if response
      console.log error if error

    Publication.documents.find({}).forEach (publication, i, cursor) =>
      # console.log publication.title
      pubId = publication._id
      pubBody = {"title": publication.title, "fullText": publication.fullText}
      pubToES = { index: 'publication', type: 'publication', id: pubId, body: pubBody }
      # console.log pubToES
      ES.index pubToES, (error, response) ->
        console.log "Response from ES: "
        console.log response if response
        console.log error if error

  'test-job': methodWrap ->
    throw new Meteor.Error 403, "Permission denied." unless Meteor.person()?.isAdmin

    new TestJob({foo: 'bar'}).enqueue()

  'process-pdfs': methodWrap ->
    throw new Meteor.Error 403, "Permission denied." unless Meteor.person()?.isAdmin

    new ProcessPublicationsJob(all: false).enqueue
      skipIfExisting: true

  'reprocess-pdfs': methodWrap ->
    throw new Meteor.Error 403, "Permission denied." unless Meteor.person()?.isAdmin

    new ProcessPublicationsJob(all: true).enqueue
      skipIfExisting: true

  'database-update-all': methodWrap ->
    throw new Meteor.Error 403, "Permission denied." unless Meteor.person()?.isAdmin

    Document.updateAll()

  'sync-arxiv-pdf-cache': methodWrap ->
    throw new Meteor.Error 403, "Permission denied." unless Meteor.person()?.isAdmin

    new ArXivBulkCacheSyncJob().enqueue
      skipIfExisting: true

  'sync-arxiv-metadata': methodWrap ->
    # If @connection is not set this means method is called from the server (eg., from auto installation)
    throw new Meteor.Error 403, "Permission denied." unless Meteor.person()?.isAdmin or not @connection

    new ArXivMetadataJob().enqueue
      skipIfExisting: true

  'sync-local-pdf-cache': methodWrap ->
    # If @connection is not set this means method is called from the server (eg., from auto installation)
    throw new Meteor.Error 403, "Permission denied." unless Meteor.person()?.isAdmin or not @connection

    new CacheSyncJob().enqueue
      skipIfExisting: true

  'sync-fsm-metadata': methodWrap ->
    throw new Meteor.Error 403, "Permission denied." unless Meteor.person()?.isAdmin

    new FSMMetadataJob().enqueue
      skipIfExisting: true

  'sync-blog': methodWrap ->
    throw new Meteor.Error 403, "Permission denied." unless Meteor.person()?.isAdmin

    # skipIfExisting not needed because cancelRepeats is set
    new TumblrJob().enqueue
      delay: 0
