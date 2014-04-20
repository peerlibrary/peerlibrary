class @Person extends Document
  # createdAt: timestamp when document was created
  # updatedAt: timestamp of this version
  # user: (null if without user account)
  #   _id
  #   emails: list with first element of user's e-mail
  #   username
  # slug: unique slug for URL
  # gravatarHash: hash for Gravatar
  # givenName
  # familyName
  # isAdmin: boolean, is user an administrator or not
  # inGroups: list of
  #   _id: id of a group the person is in
  # publications: list of
  #   _id: authored publication id
  # library: list of
  #   _id: added publication id
  # referencingAnnotations: list of (reverse field from Annotation.references.persons)
  #   _id: annotation id
  # searchResult (client only): the last search query this document is a result for, if any, used only in search results
  #   _id: id of the query, an _id of the SearchResult object for the query
  #   order: order of the result in the search query, lower number means higher

  @Meta
    name: 'Person'
    fields: =>
      user: @ReferenceField User, [emails: {$slice: 1}, 'username'], false
      publications: [@ReferenceField Publication]
      library: [@ReferenceField Publication]
      slug: @GeneratedField 'self', ['user.username']
      gravatarHash: @GeneratedField User, [emails: {$slice: 1}, 'person']

  displayName: =>
    if @givenName and @familyName
      "#{ @givenName } #{ @familyName }"
    else if @givenName
      @givenName
    else if @user?.username
      @user.username
    else
      @slug

  avatar: (size) =>
    # When used in the template without providing the size, a Handlebars argument is passed in that place (it is always the last argument)
    size = 24 unless _.isNumber size
    # TODO: We should specify default URL to the image of an avatar which is generated from name initials
    # TODO: gravatarHash does not appear
    "https://secure.gravatar.com/avatar/#{ @gravatarHash }?s=#{ size }"

  hasReadAccess: (person) =>
    true

  @requireReadAccessSelector: (person, selector) ->
    selector

  hasMaintainerAccess: (person) =>
    # User has to be logged in
    return false unless person?._id

    return true if person.isAdmin

    # TODO: Implement karma points for public documents

    return true if @_id is person._id

    return true if person._id in _.pluck @maintainerPersons, '_id'

    personGroups = _.pluck person.inGroups, '_id'
    documentGroups = _.pluck @maintainerGroups, '_id'

    return true if _.intersection(personGroups, documentGroups).length

    return false

  @requireMaintainerAccessSelector: (person, selector) ->
    unless person?._id
      # Returns a selector which does not match anything
      return _id:
        $in: []

    return selector if person.isAdmin

    # To not modify input
    selector = EJSON.clone selector

    # We use $and to not override any existing selector field
    selector.$and = [] unless selector.$and

    accessConditions = [
      _id: person._id
    ,
      'maintainerPersons._id': person._id
    ,
      'maintainerGroups._id':
        $in: _.pluck person.inGroups, '_id'
    ]

    selector.$and.push
      $or: accessConditions
    selector

  hasAdminAccess: (person) =>
    # User has to be logged in
    return false unless person?._id

    return true if person.isAdmin

    # TODO: Implement karma points for public publications

    return true if person._id in _.pluck @adminPersons, '_id'

    personGroups = _.pluck person.inGroups, '_id'
    documentGroups = _.pluck @adminGroups, '_id'

    return true if _.intersection(personGroups, documentGroups).length

    return false

  @requireAdminAccessSelector: (person, selector) ->
    unless person?._id
      # Returns a selector which does not match anything
      return _id:
        $in: []

    return selector if person.isAdmin

    # To not modify input
    selector = EJSON.clone selector

    # We use $and to not override any existing selector field
    selector.$and = [] unless selector.$and

    accessConditions = [
      'adminPersons._id': person._id
    ,
      'adminGroups._id':
        $in: _.pluck person.inGroups, '_id'
    ]

    selector.$and.push
      $or: accessConditions
    selector

  hasRemoveAccess: (person) =>
    @hasAdminAccess person

  @requireRemoveAccessSelector: (person, selector) ->
    @requireAdminAccessSelector person, selector

  @applyDefaultAccess: (personId, document) ->
    document

Meteor.person = (userId) ->
  # Meteor.userId is reactive
  userId ?= Meteor.userId()

  return null unless userId

  Person.documents.findOne
    'user._id': userId

Meteor.personId = (userId) ->
  # Meteor.userId is reactive
  userId ?= Meteor.userId()

  return null unless userId

  person = Person.documents.findOne
    'user._id': userId
  ,
    _id: 1

  person?._id or null
