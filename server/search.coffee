SEARCH_PROPOSE_LIMIT = 10
SEARCH_RESULTS_FIELDS = [
  'title'
  'authors'
  'created'
  'updated'
]

Meteor.methods
  # "key" is parsed user-provided string serving as keyword
  # "filter" is internal filter field so that "value" can be mapped to filters
  'search-propose': (query) ->
    # TODO: For now we just ignore query, we should do something smart with it
    proposals = Publications.find({cached: true, processed: true}, limit: SEARCH_PROPOSE_LIMIT - 1).map (publication) ->
      [
        key: "publication titled"
        filter: "title"
        value: publication.title
      ,
        key: "by"
        filter: "authors"
        value: "#{ publication.authors[0].lastName } et al."
      ]
    proposals.push [
      key: ""
      filter: "contains"
      value: query
    ]
    proposals

Meteor.publish 'search-results', (query, limit) ->
  if not query
    return

  if _.isString(query)
    # TODO: We should parse it here in a same way as we would parse in search-propose, and take the best interpretation
    realQuery = [
      key: ""
      filter: "contains"
      value: query
    ]
  else
    # TODO: Validate?
    realQuery = query

  # TODO: Do some real seaching
  # TODO: How to influence order of results? Should we have just simply a field?
  # TODO: Escape query in regexp
  # TODO: Make sure that searchResult field cannot be stored on the server by accident
  handle = Publications.find({cached: true, processed: true, title: new RegExp(query, 'i')},
    limit: limit
    fields: _.pick Publication.publicFields().fields, SEARCH_RESULTS_FIELDS
  ).observeChanges
    added: (id, fields) =>
      # TODO: Check if for second query with same id, is searchResult field updated or is the old one kept on the client?
      fields.searchResult =
        query: query
        # TODO: Implement
        order: 1

      @added 'Publications', id, fields

    changed: (id, fields) =>
      # TODO: Maybe order changed now?
      # We just pass on the changes
      @changed 'Publications', id, fields

    removed: (id) =>
      # We remove from the search results and leave to some other publish function to remove whole document
      @changed 'Publications', id, searchResult: undefined

  @ready()

  @onStop =>
    handle.stop()
