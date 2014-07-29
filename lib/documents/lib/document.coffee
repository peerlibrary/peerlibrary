@ACCESS =
  PRIVATE: 0
  PUBLIC: 1

@ROLES =
  ADMIN: 3
  MAINTAINER: 2
  READ_ACCESS: 1

class @BaseDocument extends Document
  @Meta
    abstract: true

  @verboseName: ->
    @Meta._name.toLowerCase()

  @verboseNamePlural: ->
    "#{ @verboseName() }s"

  @verboseNameWithCount: (quantity) ->
    quantity = 0 unless quantity
    return "1 #{ @verboseName() }" if quantity == 1
    "#{ quantity } #{ @verboseNamePlural() }"

class @AccessDocument extends BaseDocument
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
      readPersons: [@ReferenceField Person, ['slug', 'displayName', 'gravatarHash', 'user.username']]
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
    @ACCESS.PRIVATE

  @applyDefaultAccess: (personId, document) ->
    document = super

    document.access = @defaultAccess() if not document.access?
    document.readPersons ?= []
    document.readGroups ?= []

    document

class @BasicAccessDocument extends ReadAccessDocument
  # When access is private, maintainers and admins should also be
  # added to read access list so that if access is changed to public
  # and then their maintainer or admin permission is revoked, they
  # still retain read access if document is after all that switched
  # back to private access. This logic is matched in
  # server/lib/access.coffee's setRole function.
  @_applyDefaultAccess: (personId, document) ->
    if document.access is ACCESS.PRIVATE
      document.adminPersons ?= []
      for admin in document.adminPersons
        if admin._id not in _.pluck document.readPersons, '_id'
          document.readPersons ?= []
          document.readPersons.push
            _id: admin._id

      document.adminGroups ?= []
      for admin in document.adminGroups
        if admin._id not in _.pluck document.readGroups, '_id'
          document.readGroups ?= []
          document.readGroups.push
            _id: admin._id

      document.maintainerPersons ?= []
      for maintainer in document.maintainerPersons
        if maintainer._id not in _.pluck document.readPersons, '_id'
          document.readPersons ?= []
          document.readPersons.push
            _id: maintainer._id

      document.maintainerGroups ?= []
      for maintainer in document.maintainerGroups
        if maintainer._id not in _.pluck document.readGroups, '_id'
          document.readGroups ?= []
          document.readGroups.push
            _id: maintainer._id

    document
