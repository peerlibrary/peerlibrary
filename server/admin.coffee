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
