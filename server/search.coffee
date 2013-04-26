do -> # To not pollute the namespace
  SEARCH_PROPOSE_LIMIT = 10

  Meteor.methods
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

  Meteor.publish 'search-results', (query) ->
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

    queryId = Meteor.uuid()

    # TODO: Do some real seaching
    # TODO: How to influence order of results? Should we have just simply a field?
    handle = Publications.find({cached: true, processed: true}, {limit: 100}).observeChanges
      added: (id, fields) =>
        # TODO: Currently, we are adding whole query so that results can be identified if there are multiple serch queries going on at the same time, we should probably allow client to supply some query ID or something?
        @added 'SearchResults', queryId + '-' + id, {publicationId: id, query: query}
      removed: (id) =>
        @removed 'SearchResults', queryId + '-' + id

    @ready()

    @onStop =>
      handle.stop()
