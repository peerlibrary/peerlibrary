class @HasAbstractMiddleware extends PublishMiddleware
  added: (publish, collection, id, fields) =>
    return super unless collection is 'Publications'

    fields.hasAbstract = !!fields.abstract
    delete fields.abstract

    super

  changed: (publish, collection, id, fields) =>
    return super unless collection is 'Publications'

    if 'abstract' of fields
      fields.hasAbstract = !!fields.abstract
      delete fields.abstract

    super

# This middleware requires that "person" is set in publish context previously.
class @HasCachedIdMiddleware extends PublishMiddleware
  _hasCachedId: (publish, id, fields) =>
    if fields.access isnt Publication.ACCESS.CLOSED
      # Both other cases are handled by the selector, if publication is in the
      # query results, user has access to the full text of the publication
      # (publication is private or open access).
      return true
    else
      # This is not perfect because publication object lacks many fields from
      # Publication.readAccessSelfFields(), but this will impact only users
      # with more permissions over the publication and they probably will not
      # be confused with lack of a full text link. On the other hand, we could
      # request all those fields from the database, but then we would have to
      # locally cache between changed callbacks where only one of those fields
      # might change, but we need all of them available to compute access.
      # We would have to locally cache for the same reasons even in cases when
      # were are using middleware in publish endpoints which request all necessary
      # fields and not just search-related publish endpoints.
      return new Publication(_.extend {}, {_id: id}, fields).hasCacheAccessSearchResult publish.get 'person'

  added: (publish, collection, id, fields) =>
    return super unless collection is 'Publications'

    fields.hasCachedId = @_hasCachedId publish, id, fields
    delete fields.cachedId

    super

  changed: (publish, collection, id, fields) =>
    return super unless collection is 'Publications'

    fields.hasCachedId = @_hasCachedId publish, id, fields if 'access' of fields
    delete fields.cachedId

    super unless _.isEmpty fields

class @LimitImportingMiddleware extends PublishMiddleware
  _importing: (publish, id, fields) =>
    for importing in fields.importing when importing.person?._id and publish.personId and importing.person._id is publish.personId
      return [
        # We limit only to the filename
        filename: importing.filename
      ]
    # Otherwise
    []

  added: (publish, collection, id, fields) =>
    return super unless collection is 'Publications'

    fields.importing = @_importing publish, id, fields if 'importing' of fields

    super

  changed: (publish, collection, id, fields) =>
    return super unless collection is 'Publications'

    fields.importing = @_importing publish, id, fields if 'importing' of fields

    super
