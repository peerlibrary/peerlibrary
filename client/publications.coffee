Catalog.create 'publications', Publication,
  main: Template.publications
  empty: Template.noPublications
  loading: Template.publicationsLoading
,
  active: 'publicationsActive'
  ready: 'currentPublicationsReady'
  loading: 'currentPublicationsLoading'
  count: 'currentPublicationsCount'
  filter: 'currentPublicationsFilter'
  limit: 'currentPublicationsLimit'
  sort: 'currentPublicationsSort'

Deps.autorun ->
  if Session.equals 'publicationsActive', true
    Meteor.subscribe 'my-publications'

Template.publications.catalogSettings = ->
  settings =
    collection: "publications"
    sorting: [
      name: 'last active'
      sort: [
        ['updatedAt', 'desc']
        ['title', 'asc']
      ]
    ,
      name: 'title'
      sort: [
        ['title', 'asc']
      ]
    ]
    variables:
      filter: 'currentPublicationsFilter'
      sort: 'currentPublicationsSort'
      sortName: 'currentPublicationsSortName'

  settings
