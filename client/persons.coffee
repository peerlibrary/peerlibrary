Catalog.create 'persons', Person,
  main: Template.persons
  count: Template.personsCount
  loading: Template.personsLoading
,
  active: 'personsActive'
  ready: 'currentPersonsReady'
  loading: 'currentPersonsLoading'
  count: 'currentPersonsCount'
  filter: 'currentPersonsFilter'
  limit: 'currentPersonsLimit'
  sort: 'currentPersonsSort'

Template.persons.catalogSettings = ->
  documentClass: Person
  variables:
    filter: 'currentPersonsFilter'
    sort: 'currentPersonsSort'

Template.personInlineItem.status = ->
  if @user then "Registered User" else "Unregistered Person"

Template.personCatalogItem.events =
  'mousedown': (e, template) ->
    # Save mouse position so we can later detect selection actions in click handler
    template.data._previousMousePosition =
      pageX: e.pageX
      pageY: e.pageY

  'click': (e, template) ->
    # Don't redirect if user interacted with one of the actionable controls on the item
    return if $(e.target).closest('.actionable').length > 0

    e.previousMousePosition = template.data._previousMousePosition
    template.data._previousMousePosition = null

    # Don't redirect if this might have been a selection
    return if e.previousMousePosition and (Math.abs(e.previousMousePosition.pageX - e.pageX) > 1 or Math.abs(e.previousMousePosition.pageY - e.pageY) > 1)

    # Redirect user to the person
    Meteor.Router.toNew Meteor.Router.personPath template.data.slug

Template.personCatalogItem.avatarSize = ->
  100

Template.personCatalogItem.publicationsCountDescription = ->
  Publication.verboseNameWithCount @publications.length

Template.personCatalogItem.groupsCountDescription = ->
  Group.verboseNameWithCount @inGroups.length
