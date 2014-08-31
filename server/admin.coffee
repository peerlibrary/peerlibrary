Meteor.methods
  'sample-data': methodWrap ->
    # If @connection is not set this means method is called from the server (eg., from auto installation)
    throw new Meteor.Error 403, "Permission denied." unless Meteor.person()?.isAdmin or not @connection

    # Currently, a sample is simply current smaller set of arXiv metadata
    # publications which then has cache synced with PDFs from the central server
    # TODO: Think how to make a better sample which would contain both metadata and content
    Meteor.call 'sync-arxiv-metadata'

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
