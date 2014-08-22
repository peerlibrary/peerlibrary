Template.persons.catalogSettings = ->
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
  signedOutNoDocumentsMessage: "Sign up and become the first."

Template.personAvatar.status = ->
  if @user then "Registered User" else "Unregistered Person"

EnableCatalogItemLink Template.personCatalogItem

Template.personCatalogItem.person = ->
  _.extend @,
    avatarSize: 100

Template.personCatalogItem.publicationsCountDescription = ->
  Publication.verboseNameWithCount @publications.length

Template.personCatalogItem.groupsCountDescription = ->
  Group.verboseNameWithCount @inGroups.length
