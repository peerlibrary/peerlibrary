Template.persons.helpers
  catalogSettings: ->
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

Template.personAvatar.helpers
  status: ->
    return unless @_id
    if @user then "Registered User" else "Unregistered Person"

EnableCatalogItemLink Template.personCatalogItem

Template.personCatalogItem.helpers
  publicationsCountDescription: ->
    Publication.verboseNameWithCount @publications.length

  groupsCountDescription: ->
    Group.verboseNameWithCount @inGroups.length

# We use refresh before getDisplayName to merge subdocuments with all fields known on the client side.
# This makes sure that on lists where also invited persons are displayed, their emails are displayed as
# displayName to inviters (emails are not stored in subdocuments, but are subscribed to independently
# and received as invitedEmail field).
Template.personInlineItem.helpers
  getDisplayName: ->
    return unless @_id
    @refresh().getDisplayName true
