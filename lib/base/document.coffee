class @Document
  constructor: (doc) ->
    _.extend @, doc

  @_Reference: class
    constructor: (@targetCollection, @fields) ->
      @fields ?= []

    contributeToClass: (@sourceCollection, @sourceField, @isList) =>

  @Reference: (args...) ->
    new @_Reference args...

  @Meta: (meta) ->
    # First we register the current document into a global list (Document.Meta.list)
    @Meta.list.push @

    # Then we override Meta for the current document
    @Meta = meta
    @_initialize()

  @Meta.list = []

  @_initialize: ->
    fields = {}
    for field, reference of @Meta.fields or {}
      isList = _.isArray reference
      reference = reference[0] if isList
      reference.contributeToClass @Meta.collection, field, isList
      fields[field] = reference
    @Meta.fields = fields