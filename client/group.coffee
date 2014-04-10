Deps.autorun ->
  currentGroupId = Session.get 'currentGroupId'

  if currentGroupId
    Meteor.subscribe 'groups-by-id', currentGroupId

Deps.autorun ->
  group = Group.documents.findOne Session.get('currentGroupId'),
    fields:
      _id: 1
      slug: 1

  return unless group

  # currentGroupSlug is null if slug is not present in location, so we use
  # null when group.slug is empty string to prevent infinite looping
  return if Session.equals 'currentGroupSlug', (group.slug or null)

  Meteor.Router.toNew Meteor.Router.groupPath group._id, group.slug

Template.group.group = ->
  Group.documents.findOne Session.get 'currentGroupId'

Template.group.currentUserIsMember = ->
  Meteor.personId() in _.pluck Group.documents.findOne(Session.get('currentGroupId'))?.members, '_id'

Template.group.events
  'submit .add-member': (e, template) ->
    e.preventDefault()

    # TODO: We should use autocomplete to get information about users with a given name so that when an user is chosen, we have their ID we use here, "name" here is currently misleading because it has to be raw ID with this code
    newMemberId = $(template.findAll '.name').val()

    return unless newMemberId

    return if newMemberId in _.pluck Group.documents.findOne(Session.get('currentGroupId')).members, '_id'

    Meteor.call 'add-to-group', Session.get('currentGroupId'), newMemberId, (error, count) ->
      return Notify.meteorError error if error

      Notify.success "Member added." if count

    return # Make sure CoffeeScript does not return anything
