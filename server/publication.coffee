class @Publication extends @Publication
  checkCache: =>
    if @cached
      return

    if not Storage.exists @filename()
      console.log "Caching PDF for #{ @_id } from the central server"

      pdf = HTTP.get 'http://stage.peerlibrary.org' + @url(),
        timeout: 10000 # ms
        encoding: null # PDFs are binary data

      Storage.save @filename(), pdf.content

    @cached = true
    Publications.update @_id, $set: cached: @cached

    pdf?.content

  process: (pdf, initCallback, textCallback, pageImageCallback, progressCallback) =>
    pdf ?= Storage.open @filename()
    initCallback ?= (numberOfPages) ->
    textCallback ?= (pageNumber, x, y, width, height, direction, text) ->
    pageImageCallback ?= (pageNumber, canvasElement) ->
    progressCallback ?= ->

    console.log "Processing PDF for #{ @_id }: #{ @filename() }"

    PDF.process pdf, initCallback, textCallback, pageImageCallback, progressCallback

    @processed = true
    Publications.update @_id, $set: processed: @processed

  # A subset of public fields used for search results to optimize transmission to a client
  # This list is applied to PUBLIC_FIELDS to get a subset
  @PUBLIC_SEARCH_RESULTS_FIELDS: ->
    [
      'slug'
      'created'
      'updated'
      'authors'
      'title'
      'numberOfPages'
    ]

  # A set of fields which are public and can be published to the client
  @PUBLIC_FIELDS: ->
    fields:
      slug: 1
      created: 1
      updated: 1
      authors: 1
      title: 1
      numberOfPages: 1
      abstract: 1
      doi: 1
      foreignId: 1
      source: 1
      importing: 1

Meteor.methods
  createPublication: (filename) ->
    if this.userId is null
      throw new Meteor.Error 403, 'User is not logged in.'

    Publications.insert
      created: moment.utc().toDate()
      updated: moment.utc().toDate()
      source: 'upload'
      importing:
        by:
          id: this.userId
        filename: filename
        progress: 0
      cached: false
      processed: false

  uploadPublication: (file) ->
    Publications.update
      _id: file.name.split('.')[0]
      'importing.by.id': this.userId
    ,
      $set:
        'importing.progress': ~~(100 * file.end / file.size)

    dirName = Storage._storageDirectory + Storage._path.sep + Publication._filenamePrefix()

    # Create directory if it does not exist
    Storage._assurePath dirName + Publication._uploadFilename ''

    file.save dirName + 'upload', {}

  finishPublicationUpload: (id) ->
    Publications.update
      _id: id
      'importing.by.id': this.userId
    ,
      $set:
        cached: true

  confirmPublication: (id, metadata) ->
    Publications.update
      _id: id
      'importing.by.id': this.userId
      cached: true
    ,
      $set:
        _.extend _.pick(metadata or {}, 'authorsRaw', 'title', 'abstract', 'doi'),
          updated: moment.utc().toDate()
      $unset:
        importing: ''

Meteor.publish 'publications-by-author-slug', (authorSlug) ->
  if not authorSlug
    return

  author = Persons.findOne
    slug: authorSlug

  Publications.find
    authorIds:
      $all: [author._id]
    cached: true
    processed: true
  ,
    Publication.PUBLIC_FIELDS()

Meteor.publish 'publications-by-id', (id) ->
  if not id
    return

  Publications.find
    _id: id
    cached: true
    processed: true
  ,
    Publication.PUBLIC_FIELDS()

Meteor.publish 'publications-by-ids', (ids) ->
  if not ids
    return

  Publications.find
    _id: {$in: ids}
    cached: true
    processed: true
  ,
    Publication.PUBLIC_FIELDS()

Meteor.publish 'publications-importing', ->
  Publications.find
    'importing.by.id': this.userId
  ,
    fields: _.extend Publication.PUBLIC_FIELDS().fields,
      cached: 1
      processed: 1