do -> # To not pollute the namespace
  SEARCH_PROPOSE_LIMIT = 10

  Meteor.methods
    'search-propose': (query) ->
      # TODO: For now we just ignore query, we should do something smart with it
      proposals = Publications.find({}, limit: SEARCH_PROPOSE_LIMIT - 1).map (publication) ->
        [
          key: "publication titled"
          value: publication.title
        ,
          key: "by"
          value: "#{ publication.authors[0].lastName } et al."
        ]
      proposals.push [
        key: "containing"
        value: query
      ]
      proposals

  Meteor.publish 'search-results', (query) ->
    if _.isString(query)
      # TODO: We should parse it here in a same way as we would parse in search-propose, and take the best interpretation
      query = [
        key: "containing"
        value: query
      ]

    # TODO: Do some real seaching
    handle = Publications.find().observeChanges
      added: (id, fields) =>
        @added 'search-results', id, {}
      removed: (id) =>
        @removed 'search-results', id

    @ready()

    @onStop =>
      handle.stop()
