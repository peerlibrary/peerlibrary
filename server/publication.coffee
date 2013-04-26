class Publication extends Publication
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

    if pdf.statusCode and pdf.statusCode == 404
      console.warn "Not found"
      return
    else if pdf.statusCode and pdf.statusCode != 200
      console.error "Caching PDF failed: #{ pdf.statusCode }", pdf.content
      throw new Meteor.Error 500, "Caching PDF failed: #{ pdf.statusCode }", pdf.content
    else if pdf.error
      console.error pdf.error
      throw pdf.error

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

do -> # To not pollute the namespace
  Meteor.publish 'publications-by-owner', (owner) ->
    Publications.find
      owner: owner
    ,
      Publication.publicFields()

  Meteor.publish 'publications-by-id', (id) ->
    Publications.find id, Publication.publicFields()

  Meteor.publish 'publications-by-ids', (ids) ->
    Publications.find {_id: {$in: ids}}, Publication.publicFields()
