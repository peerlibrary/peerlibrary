updateSource = (reference, id, fields) ->
  selector = {}
  selector["#{ reference.sourceField }._id"] = id

  update = {}
  for field, value of fields
    if reference.isList
      field = "#{ reference.sourceField }.$.#{ field }"
    else
      field = "#{ reference.sourceField }.#{ field }"
    if _.isUndefined value
      update['$unset'] ?= {}
      update['$unset'][field] = ''
    else
      update['$set'] ?= {}
      update['$set'][field] = value

  reference.sourceCollection.update selector, update, multi: true

removeSource = (reference, id) ->
  selector = {}
  selector["#{ reference.sourceField }._id"] = id

  if reference.isList
    field = "#{ reference.sourceField }.$"
    update =
      $unset: {}
    update['$unset'][field] = ''

    # MongoDB supports removal of list elements only in two steps
    # First, we set all removed references to null
    reference.sourceCollection.update selector, update, multi: true

    # Then we remove all null elements
    selector = {}
    selector[reference.sourceField] = null
    update =
      $pull: {}
    update['$pull'][reference.sourceField] = null

    reference.sourceCollection.update selector, update, multi: true

  else
    reference.sourceCollection.remove selector

setupObserver = (reference) ->
  fields =
    _id: 1 # In the case we want only id, that is, detect deletions
  for field in reference.fields
    fields[field] = 1

  reference.targetCollection.find({}, fields: fields).observeChanges
    added: (id, fields) ->
      return if _.isEmpty fields

      updateSource reference, id, fields

    changed: (id, fields) ->
      updateSource reference, id, fields

    removed: (id) ->
      removeSource reference, id

setupObservers = ->
  for document in Document.Meta.list
    for field, reference of document.Meta.fields
      setupObserver reference

Meteor.startup ->
  setupObservers()