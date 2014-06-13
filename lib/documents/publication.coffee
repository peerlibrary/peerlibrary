class @Publication extends ReadAccessDocument
  # access: 0 (private, Publication.ACCESS.PRIVATE), 1 (closed, Publication.ACCESS.CLOSED), 2 (open, Publication.ACCESS.OPEN)
  # readPersons: if private access, list of persons who have read permissions
  # readGroups: if private access, list of groups who have read permissions
  # maintainerPersons: list of persons who have maintainer permissions
  # maintainerGroups: ilist of groups who have maintainer permissions
  # adminPersons: list of persons who have admin permissions
  # adminGroups: ilist of groups who have admin permissions
  # TODO: We should probably have a separate timestamp for when publication was orignally published
  # createdAt: timestamp when the publication was published (we match PeerLibrary document creation date with publication publish date)
  # TODO: We sometimes use "foreign", sometimes "raw", should we unify this?
  # createdRaw: unparsed created string
  # updatedAt: timestamp when the publication (or its metadata) was last updated
  # slug: slug for URL
  # authors: list of
  #   _id: author's person id
  #   slug: author's person id
  #   givenName
  #   familyName
  #   user
  #     username
  # authorsRaw: unparsed authors string
  # title
  # comments: comments about the publication, a free-form text, metadata provided by the source
  # abstract
  # hasAbstract (client only): boolean if document has an abstract, used only in search results (cheaper to send than the whole abstract)
  # doi
  # msc2010: list of MSC 2010 classes
  # acm1998: list of ACM 1998 classes
  # foreignId: id of the publication used by the source
  # foreignUrl: URL of a foreign content file (to cache)
  # foreignCategories: categories metadata provided by the source
  # foreignJournalReference: journal reference metadata provided by the source
  # source: a string identifying where was this publication fetched from
  # sha256: SHA-256 hash of the file
  # size: size of the file (if cached)
  # importing: (temporary) list of
  #   createdAt: timestamp when this instance of importing file was created
  #   updatedAt: timestamp when this instance of importing file was last updated (the last file chunk received)
  #   person: person importing the document
  #   filename: original name of the imported file
  #   importingId: used for the temporary filename of the importing file
  # cached: timestamp when the publication was cached
  # cachedId: used for the the cached filename (availble for open access publications, if user has the publication in the library, or is a private publication)
  # mediaType: which media type a cached file is (currently supported: pdf, tei)
  # processed: timestamp when the publication was processed (file checked, text extracted, thumbnails generated, etc.)
  # processError:
  #   error: description of the publication processing error
  #   stack: stack trace of the error
  # numberOfPages
  # fullText: full plain text content suitable for searching
  # annotations: list of (reverse field from Annotation.publication)
  #   _id: annotation id
  # referencingAnnotations: list of (reverse field from Annotation.references.publications)
  #   _id: annotation id
  # license: license information, if known
  # searchResult (client only): the last search query this document is a result for, if any, used only in search results
  #   _id: id of the query, an _id of the SearchResult object for the query
  #   order: order of the result in the search query, lower number means higher

  @Meta
    name: 'Publication'
    fields: =>
      maintainerPersons: [@ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username']]
      maintainerGroups: [@ReferenceField Group, ['slug', 'name']]
      adminPersons: [@ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username']]
      adminGroups: [@ReferenceField Group, ['slug', 'name']]
      authors: [@ReferenceField Person, ['slug', 'givenName', 'familyName', 'user.username'], true, 'publications']
      importing: [
        person: @ReferenceField Person
      ]
      slug: @GeneratedField 'self', ['title']
      fullText: @GeneratedField 'self', ['cached', 'cachedId', 'mediaType', 'processed', 'processError']
    triggers: =>
      updatedAt: UpdatedAtTrigger ['createdRaw', 'authors._id', 'authorsRaw', 'title', 'comments', 'abstract', 'doi', 'msc2010', 'acm1998', 'foreignId', 'foreignCategories', 'foreignJournalReference', 'source', 'sha256', 'size', 'cached','processed', 'processError', 'license']

  @_filenamePrefix: ->
    'publication' + Storage._path.sep

  cachedFilename: =>
    throw new Error "Cached filename not available" unless @cachedId and @mediaType

    Publication._filenamePrefix() + 'cache' + Storage._path.sep + @cachedId + '.' + @mediaType

  url: =>
    Storage.url @cachedFilename()

  thumbnail: (page) =>
    if page < 1 or page > @numberOfPages
      throw new Error "Page out of bounds: #{ page }/#{ @numberOfPages }"

    'thumbnail' + Storage._path.sep + @_id + Storage._path.sep + page + '-125x95.png'

  thumbnailUrl: (page) =>
    thumbnail = new String Storage.url @thumbnail page
    thumbnail.page = page
    # TODO: Remove when you are able to access parent context with Meteor
    thumbnail.publication = @
    thumbnail

  thumbnailUrls: =>
    @thumbnailUrl page for page in [1..@numberOfPages]

  createdDay: =>
    moment(@createdAt).format 'MMMM Do YYYY'

  @ACCESS:
    PRIVATE: ACCESS.PRIVATE
    CLOSED: 1
    OPEN: 2

  hasReadAccess: (person, cache=false) =>
    return false unless @cached

    return true if person?.isAdmin

    return true if @_id in _.pluck person?.library, '_id'

    return false unless @processed

    implementation = @_hasReadAccess person, cache
    return implementation if implementation is true or implementation is false
    implementation = @_hasMaintainerAccess person
    return implementation if implementation is true or implementation is false
    implementation = @_hasAdminAccess person
    return implementation if implementation is true or implementation is false

    return false

  _hasReadAccess: (person, cache=false) =>
    return true if @access is @constructor.ACCESS.OPEN

    if @access is @constructor.ACCESS.CLOSED
      if not cache
        return true
      else
        return

    return unless person?._id

    # Access should be private here, if it is not, we prevent access to the document
    # TODO: Should we log this?
    return false unless @access is @constructor.ACCESS.PRIVATE

    return true if person._id in _.pluck @readPersons, '_id'

    personGroups = _.pluck person.inGroups, '_id'
    documentGroups = _.pluck @readGroups, '_id'

    return true if _.intersection(personGroups, documentGroups).length

  hasCacheAccess: (person) =>
    @hasReadAccess person, true

  @requireReadAccessSelector: (person, selector, cache=false) ->
    # To not modify input
    selector = EJSON.clone selector

    # We use $and to not override any existing selector field
    selector.$and = [] unless selector.$and
    selector.$and.push
      cached:
        $exists: true

    return selector if person?.isAdmin

    deny = false
    conditions = []

    implementation = @_requireReadAccessConditions person, cache
    if _.isArray implementation
      conditions = conditions.concat implementation
    else
      deny = true

    implementation = @_requireMaintainerAccessConditions person
    if _.isArray implementation
      conditions = conditions.concat implementation
    else
      deny = true

    implementation = @_requireAdminAccessConditions person
    if _.isArray implementation
      conditions = conditions.concat implementation
    else
      deny = true

    deny = true unless conditions.length

    if deny
      selector.$and.push
        _id:
          $in: _.pluck person?.library, '_id'
    else
      selector.$and.push
        $or: [
          processed:
            $exists: true
          $or: conditions
        ,
          _id:
            $in: _.pluck person?.library, '_id'
        ]

    selector

  @requireCacheAccessSelector: (person, selector) ->
    @requireReadAccessSelector person, selector, true

  @_requireReadAccessConditions: (person, cache=false) ->
    conditions = [
      access: @ACCESS.OPEN
    ]

    if person?._id
      conditions = conditions.concat [
        access: @ACCESS.PRIVATE
        'readPersons._id': person._id
      ,
        access: @ACCESS.PRIVATE
        'readGroups._id':
          $in: _.pluck person.inGroups, '_id'
      ]

    unless cache
      # Access to publication metadata is allowed for closed access
      # publications, only access to cache information is not
      conditions.push
        access: @ACCESS.CLOSED

    conditions

  @readAccessPersonFields: ->
    _.extend @adminAccessPersonFields(), @maintainerAccessPersonFields(),
      # _id field is implicitly added
      isAdmin: 1
      inGroups: 1
      library: 1

  @readAccessSelfFields: ->
    _.extend @adminAccessSelfFields(), @maintainerAccessSelfFields(),
      # _id field is implicitly added
      cached: 1
      processed: 1
      access: 1
      readPersons: 1
      readGroups: 1

  _hasMaintainerAccess: (person) =>
    # User has to be logged in
    return unless person?._id

    # TODO: Implement karma points for public documents

    return true if person._id in _.pluck @authors, '_id'

    return true if person._id in _.pluck @maintainerPersons, '_id'

    personGroups = _.pluck person.inGroups, '_id'
    documentGroups = _.pluck @maintainerGroups, '_id'

    return true if _.intersection(personGroups, documentGroups).length

  @_requireMaintainerAccessConditions: (person) ->
    return [] unless person?._id

    [
      'authors._id': person._id
    ,
      'maintainerPersons._id': person._id
    ,
      'maintainerGroups._id':
        $in: _.pluck person.inGroups, '_id'
    ]

  @maintainerAccessPersonFields: ->
    fields = super
    _.extend fields,
      inGroups: 1

  @maintainerAccessSelfFields: ->
    fields = super
    _.extend fields,
      authors: 1
      maintainerPersons: 1
      maintainerGroups: 1

  _hasAdminAccess: (person) =>
    # User has to be logged in
    return unless person?._id

    # TODO: Implement karma points for public documents

    return true if person._id in _.pluck @adminPersons, '_id'

    personGroups = _.pluck person.inGroups, '_id'
    documentGroups = _.pluck @adminGroups, '_id'

    return true if _.intersection(personGroups, documentGroups).length

  @_requireAdminAccessConditions: (person) ->
    return [] unless person?._id

    [
      'adminPersons._id': person._id
    ,
      'adminGroups._id':
        $in: _.pluck person.inGroups, '_id'
    ]

  @adminAccessPersonFields: ->
    fields = super
    _.extend fields,
      inGroups: 1

  @adminAccessSelfFields: ->
    fields = super
    _.extend fields,
      adminPersons: 1
      adminGroups: 1

  @defaultAccess: ->
    @ACCESS.OPEN

  @applyDefaultAccess: (personId, document) ->
    document = super

    if personId and personId not in _.pluck document.adminPersons, '_id'
      document.adminPersons ?= []
      document.adminPersons.push
        _id: personId

    document
