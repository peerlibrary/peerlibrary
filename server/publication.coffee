class Publication extends @Publication
  checkCache: =>
    if @cached
      return

    if Storage.exists @filename()
      @cached = true
      Publications.update @_id, $set: cached: @cached
      return

    console.log "Caching PDF for #{ @_id } from the central server"

    pdf = Meteor.http.get 'http://stage.peerlibrary.org' + @url(true),
      timeout: 10000 # ms
      encoding: null # PDFs are binary data

    Storage.save @filename(), pdf.content

    @cached = true
    Publications.update @_id, $set: cached: @cached

    pdf.content

  process: (pdf, progressCallback) =>
    pdf ?= Storage.open @filename()
    progressCallback ?= ->

    console.log "Processing PDF for #{ @_id }: #{ @filename() }"

    PDF.process pdf, progressCallback

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
      paragraphs: 1
      cached: 1

Meteor.publish 'publications-by-owner', (owner) ->
  Publications.find
    owner: owner
  ,
    limit: 5
    fields: Publication.publicFields().fields

Meteor.publish 'publications-by-id', (id) ->
  Publications.find id, Publication.publicFields()

Meteor.publish 'publications-by-ids', (ids) ->
  Publications.find {_id: {$in: ids}},
    limit: 5
    fields: Publication.publicFields().fields

@Publication = Publication