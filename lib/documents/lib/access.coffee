@ACCESS =
  PRIVATE: 0
  PUBLIC: 1

class @AccessDocument extends Document
  @Meta
    abstract: true

  # Returning false from _hasReadAccess is same as returning non-array from
  # _requireReadAccessConditions. Returning non-boolean is same as returning
  # [] from _requireReadAccessConditions.

  hasReadAccess: (person) =>
    return true if person?.isAdmin

    implementation = @_hasReadAccess person
    return implementation if implementation is true or implementation is false
    implementation = @_hasMaintainerAccess person
    return implementation if implementation is true or implementation is false
    implementation = @_hasAdminAccess person
    return implementation if implementation is true or implementation is false

    return false

  _hasReadAccess: (person) =>

  @requireReadAccessSelector: (person, selector) ->
    return selector if person?.isAdmin

    conditions = []

    implementation = @_requireReadAccessConditions person
    return _id: $in: [] unless _.isArray implementation
    conditions = conditions.concat implementation

    implementation = @_requireMaintainerAccessConditions person
    return _id: $in: [] unless _.isArray implementation
    conditions = conditions.concat implementation

    implementation = @_requireAdminAccessConditions person
    return _id: $in: [] unless _.isArray implementation
    conditions = conditions.concat implementation

    return _id: $in: [] unless conditions.length

    # To not modify input
    selector = EJSON.clone selector

    # We use $and to not override any existing selector field
    selector.$and = [] unless selector.$and
    selector.$and.push
      $or: conditions

    selector

  @_requireReadAccessConditions: (person) ->
    []

  @readAccessPersonFields: ->
    _.extend @adminAccessPersonFields(), @maintainerAccessPersonFields(),
      # _id field is implicitly added
      isAdmin: 1

  @readAccessSelfFields: ->
    _.extend @adminAccessSelfFields(), @maintainerAccessSelfFields(),
      _id: 1 # To make sure we do not select all fields

  hasMaintainerAccess: (person) =>
    return true if person?.isAdmin

    implementation = @_hasMaintainerAccess person
    return implementation if implementation is true or implementation is false
    implementation = @_hasAdminAccess person
    return implementation if implementation is true or implementation is false

    return false

  _hasMaintainerAccess: (person) =>

  @requireMaintainerAccessSelector: (person, selector) ->
    return selector if person?.isAdmin

    conditions = []

    implementation = @_requireMaintainerAccessConditions person
    return _id: $in: [] unless _.isArray implementation
    conditions = conditions.concat implementation

    implementation = @_requireAdminAccessConditions person
    return _id: $in: [] unless _.isArray implementation
    conditions = conditions.concat implementation

    return _id: $in: [] unless conditions.length

    # To not modify input
    selector = EJSON.clone selector

    # We use $and to not override any existing selector field
    selector.$and = [] unless selector.$and
    selector.$and.push
      $or: conditions

    selector

  @_requireMaintainerAccessConditions: (person) ->
    []

  @maintainerAccessPersonFields: ->
    _.extend @adminAccessPersonFields(),
      # _id field is implicitly added
      isAdmin: 1

  @maintainerAccessSelfFields: ->
    _.extend @adminAccessSelfFields(),
      _id: 1 # To make sure we do not select all fields

  hasAdminAccess: (person) =>
    return true if person?.isAdmin

    implementation = @_hasAdminAccess person
    return implementation if implementation is true or implementation is false

    return false

  _hasAdminAccess: (person) =>

  @requireAdminAccessSelector: (person, selector) ->
    return selector if person?.isAdmin

    conditions = []

    implementation = @_requireAdminAccessConditions person
    return _id: $in: [] unless _.isArray implementation
    conditions = conditions.concat implementation

    return _id: $in: [] unless conditions.length

    # To not modify input
    selector = EJSON.clone selector

    # We use $and to not override any existing selector field
    selector.$and = [] unless selector.$and
    selector.$and.push
      $or: conditions

    selector

  @_requireAdminAccessConditions: (person) ->
    []

  @adminAccessPersonFields: ->
    # _id field is implicitly added
    isAdmin: 1

  @adminAccessSelfFields: ->
    _id: 1 # To make sure we do not select all fields

  hasRemoveAccess: (person) =>
    # Default is same as maintainer access
    @hasMaintainerAccess person

  @requireRemoveAccessSelector: (person, selector) ->
    # Default is same as maintainer access
    @requireMaintainerAccessSelector person, selector

  @removeAccessPersonFields: ->
    @maintainerAccessPersonFields()

  @removeAccessSelfFields: ->
    @maintainerAccessSelfFields()

  @applyDefaultAccess: (personId, document) ->
    document

class @ReadAccessDocument extends AccessDocument
  # access: 0 (private, ACCESS.PRIVATE), 1 (public, ACCESS.PUBLIC)
  # readPersons: if private access, list of persons who have read permissions
  # readGroups: if private access, list of groups who have read permissions

  @Meta
    abstract: true
    fields: =>
      readPersons: [@ReferenceField Person, ['slug', 'givenName', 'familyName', 'gravatarHash', 'user.username']]
      readGroups: [@ReferenceField Group, ['slug', 'name']]

  @ACCESS:
    PRIVATE: ACCESS.PRIVATE
    PUBLIC: ACCESS.PUBLIC

  _hasReadAccess: (person) =>
    return true if @access is @constructor.ACCESS.PUBLIC

    return unless person?._id

    # Access should be private here, if it is not, we prevent access to the document
    # TODO: Should we log this?
    return false unless @access is @constructor.ACCESS.PRIVATE

    return true if person._id in _.pluck @readPersons, '_id'

    personGroups = _.pluck person.inGroups, '_id'
    annotationGroups = _.pluck @readGroups, '_id'

    return true if _.intersection(personGroups, annotationGroups).length

  @_requireReadAccessConditions: (person) ->
    if person?._id
      [
        access: @ACCESS.PUBLIC
      ,
        access: @ACCESS.PRIVATE
        'readPersons._id': person._id
      ,
        access: @ACCESS.PRIVATE
        'readGroups._id':
          $in: _.pluck person.inGroups, '_id'
      ]
    else
      [
        access: @ACCESS.PUBLIC
      ]

  @readAccessPersonFields: ->
    fields = super
    _.extend fields,
      inGroups: 1

  @readAccessSelfFields: ->
    fields = super
    _.extend fields,
      access: 1
      readPersons: 1
      readGroups: 1

  @defaultAccess: ->
    @ACCESS.PUBLIC

  @applyDefaultAccess: (personId, document) ->
    document = super

    document.access = @defaultAccess() if not document.access?
    document.readPersons ?= []
    document.readGroups ?= []

    document
