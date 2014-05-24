Catalog.create 'persons', Person,
  main: Template.persons
  empty: Template.noPersons
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
