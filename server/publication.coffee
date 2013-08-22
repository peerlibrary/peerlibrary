class Publication extends @Publication
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

  @publicSearchResultFields: ->
    [
      'slug'
      'created'
      'updated'
      'authors'
      'title'
      'numberOfPages'
    ]

  @publicFields: ->
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

Meteor.publish 'publications-by-owner', (owner) ->
  if not owner
    return

  Publications.find
    owner: owner
    cached: true
    processed: true
  ,
    Publication.publicFields()

Meteor.publish 'publications-by-id', (id) ->
  if not id
    return

  Publications.find
    _id: id
    cached: true
    processed: true
  ,
    Publication.publicFields()

Meteor.publish 'publications-by-ids', (ids) ->
  if not ids
    return

  Publications.find
    _id: {$in: ids}
    cached: true
    processed: true
  ,
    Publication.publicFields()

@Publication = Publication
