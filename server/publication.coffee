class Publication extends Publication
  checkCache: =>
    if Storage.exists @filename()
      @cached = true
      Publications.update @_id, $set: cached: @cached

  process: (pdf, progressCallback) =>
    pdf ?= Storage.open @filename()
    progressCallback ?= ->
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
