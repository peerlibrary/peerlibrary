@ACCESS =
  PRIVATE: 0
  PUBLIC: 1

@hasReadAccess = (document, person) ->
  return true if person?.isAdmin

  return true if document.access is Annotation.ACCESS.PUBLIC

  # We assume document.access is private here

  return false unless person?._id

  return true if person._id in _.pluck document.readPersons, '_id'

  personGroups = _.pluck person?.inGroups, '_id'
  annotationGroups = _.pluck document.readGroups, '_id'

  return true if _.intersection(personGroups, annotationGroups).length

  return false

@requireReadAccessSelector = (person, selector) ->
  return selector if person?.isAdmin

  # We use $or inside of $and to not override any existing $or
  selector.$and = [] unless selector.$and
  selector.$and.push
    $or: [
      access: ACCESS.PUBLIC
    ,
      access: ACCESS.PRIVATE
      'readPersons._id': person?._id
    ,
      access: ACCESS.PRIVATE
      'readGroups._id':
        $in: _.pluck person?.inGroups, '_id'
    ]
  selector

class @AccessDocument extends Document
  # access: 0 (private), 1 (public)
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

  hasReadAccess: (person) =>
    hasReadAccess @, person

  @requireReadAccessSelector: (person, selector) ->
    requireReadAccessSelector person, selector

  @defaultAccess: ->
    @ACCESS.PRIVATE

  @applyDefaultAccess: (document, personId) ->
    document.access = @defaultAccess() if not document.access?

    # Makes sure we do not get locked out
    if document.access is @ACCESS.PRIVATE
      if personId not in _.pluck document.readPersons, '_id'
        document.readPersons ?= []
        document.readPersons.push
          _id: personId

    document
