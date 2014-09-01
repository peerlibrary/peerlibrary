# TODO: Search for persons as well
Meteor.publish 'search-results', (query, limit) ->
  validateArgument 'query', query, NonEmptyString
  validateArgument 'limit', limit, PositiveNumber

  findQuery = createQueryCriteria query, 'fullText'
  return unless findQuery.$and.length

  @related (person) ->
    restrictedFindQuery = Publication.requireReadAccessSelector person, findQuery

    searchPublish @, 'search-results', query,
      cursor: Publication.documents.find(restrictedFindQuery,
        limit: limit
        fields: Publication.PUBLISH_SEARCH_RESULTS_FIELDS().fields
      )
      added: (id, fields) =>
        fields.hasAbstract = !!fields.abstract
        delete fields.abstract
        if fields.access isnt Publication.ACCESS.CLOSED
          # Both other cases are handled by the selector, if publication is in the
          # query results, user has access to the full text of the publication
          # (publication is private or open access)
          fields.hasCachedId = true
        else
          fields.hasCachedId = new Publication(_.extend {}, {_id: id}, fields).hasCacheAccessSearchResult person
        fields
      changed: (id, fields) =>
        if 'abstract' of fields
          fields.hasAbstract = !!fields.abstract
          delete fields.abstract
        if 'access' of fields
          if fields.access isnt Publication.ACCESS.CLOSED
            # Both other cases are handled by the selector, if publication is in the
            # query results, user has access to the full text of the publication
            # (publication is private or open access)
            fields.hasCachedId = true
          else
            fields.hasCachedId = new Publication(_.extend {}, {_id: id}, fields).hasCacheAccessSearchResult person
        fields
  ,
    Person.documents.find
      _id: @personId
    ,
      fields: Publication.readAccessPersonFields()
