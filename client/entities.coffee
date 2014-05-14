# ENTITIES

Template.personEntity.avatar = ->
  # Display avatar at desired size
  @avatar @avatarSize

Template.personEntity.status = ->
  if @user then "Registered User" else "Unregistered Author"

# LISTINGS

# Publication

Template.publicationListing.events =
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

Template.publicationListing.created = ->
  @_publicationHandle = null

Template.publicationListing.rendered = ->
  $(@findAll '.scrubber').iscrubber()

Template.publicationListing.destroyed = ->
  @_publicationHandle?.stop()
  @_publicationHandle = null

Template.publicationListingTitle[method] = Template.publicationMetaMenuTitle[method] for method in ['created', 'rendered', 'destroyed']

Template.publicationListingThumbnail.events
  'click li': (e, template) ->
    root.startViewerOnPage = @page
    # TODO: Change when you are able to access parent context directly with Meteor
    publication = @publication
    Meteor.Router.toNew Meteor.Router.publicationPath publication._id, publication.slug

# Group

Template.groupListing.countDescription = ->
  if @membersCount is 1 then "1 member" else "#{ @membersCount } members"

# Collection

Template.collectionListing.countDescription = ->
  if @publications?.length is 1 then "1 publication" else "#{ @publications?.length or 0 } publications"

# MEMBERS

Template.member.entityIsPerson = ->
  @ instanceof Person

Template.member.entityIsGroup = ->
  @ instanceof Group

Template.memberAdd.entityIsPerson = Template.member.entityIsPerson
Template.memberAdd.entityIsGroup = Template.member.entityIsGroup

Template.memberAdd.noLinkEntity = ->
  # Because we cannot access parent templates we're modifying the data with an extra parameter
  # TODO: Change when Meteor allows accessing parent context
  @.noLink = true
  @

