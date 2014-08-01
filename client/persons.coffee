catalogSettings =
  subscription: 'persons'
  documentClass: Person
  variables:
    active: 'personsActive'
    ready: 'currentPersonsReady'
    loading: 'currentPersonsLoading'
    count: 'currentPersonsCount'
    filter: 'currentPersonsFilter'
    limit: 'currentPersonsLimit'
    limitIncreasing: 'currentPersonsLimitIncreasing'
    sort: 'currentPersonsSort'
  signedOutNoDocumentsMessage: "There are no people yet. Sign up and become the first."

Catalog.create catalogSettings

Template.persons.catalogSettings = ->
  catalogSettings

Template.personAvatar.status = ->
  if @user then "Registered User" else "Unregistered Person"

Template.personCatalogItem.events =
  'mousedown': (event, template) ->
    # Save mouse position so we can later detect selection actions in click handler
    template.data._previousMousePosition =
      pageX: event.pageX
      pageY: event.pageY

  'click': (event, template) ->
    # Don't redirect if user interacted with one of the actionable controls on the item
    return if $(event.target).closest('.actionable').length > 0

    # Don't redirect if this might have been a selection
    event.previousMousePosition = template.data._previousMousePosition
    return if event.previousMousePosition and (Math.abs(event.previousMousePosition.pageX - event.pageX) > 1 or Math.abs(event.previousMousePosition.pageY - event.pageY) > 1)

    # Redirect user to the person
    Meteor.Router.toNew template.data.path()

Template.personCatalogItem.avatarSize = ->
  100

Template.personCatalogItem.publicationsCountDescription = ->
  Publication.verboseNameWithCount @publications.length

Template.personCatalogItem.groupsCountDescription = ->
  Group.verboseNameWithCount @inGroups.length
