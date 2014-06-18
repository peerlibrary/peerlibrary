# Used for global variable assignments in local scopes
root = @

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

Template.publications.catalogSettings = ->
  documentClass: Publication
  variables:
    filter: 'currentPublicationsFilter'
    sort: 'currentPublicationsSort'

Template.publicationCatalogItem.events =
  'click .preview-link': (e, template) ->
    e.preventDefault()

    if template._publicationHandle
      # We ignore the click if handle is not yet ready
      $(template.findAll '.abstract').slideToggle('fast') if template._publicationHandle.ready()
    else
      template._publicationHandle = Meteor.subscribe 'publications-by-id', @_id, =>
        Deps.afterFlush =>
          $(template.findAll '.abstract').slideToggle('fast')

    return # Make sure CoffeeScript does not return anything

Template.publicationCatalogItem.created = ->
  @_publicationHandle = null

Template.publicationCatalogItem.rendered = ->
  $(@findAll '.scrubber').iscrubber()

Template.publicationCatalogItem.destroyed = ->
  @_publicationHandle?.stop()
  @_publicationHandle = null

Template.publicationCatalogItem.hasAbstract = ->
  @hasAbstract or @abstract

Editable.template Template.publicationCatalogItemTitle, ->
  @data.hasMaintainerAccess Meteor.person()
,
(title) ->
  Meteor.call 'publication-set-title', @data._id, title, (error, count) ->
    return Notify.meteorError error, true if error
,
  "Enter publication title"

Template.publicationMetaMenuTitle[method] = Template.publicationCatalogItemTitle[method] for method in ['created', 'rendered', 'destroyed']

Template.publicationCatalogItemThumbnail.events
  'click li': (e, template) ->
    root.startViewerOnPage = @page
    # TODO: Change when you are able to access parent context directly with Meteor
    publication = @publication
    Meteor.Router.toNew Meteor.Router.publicationPath publication._id, publication.slug
