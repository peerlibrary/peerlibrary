Deps.autorun ->
  slug = Session.get 'currentPersonSlug'

  if slug
    # We also search by id because we may have to redirect to canonical URL
    Meteor.subscribe 'persons-by-id-or-slug', slug
    Meteor.subscribe 'publications-by-author-slug', slug

    if slug is Meteor.person()?.slug
      Meteor.subscribe 'my-publications'
      Meteor.subscribe 'my-publications-importing'

Deps.autorun ->
  slug = Session.get 'currentPersonSlug'

  person = Persons.findOne
    $or: [
      slug: slug
    ,
      _id: slug
    ]

  return unless person

  # Assure URL is canonical
  Meteor.Router.toNew Meteor.Router.profilePath person.slug unless slug is person.slug

Template.profile.person = ->
  Persons.findOne
    # We can search by slug because we assured that the URL is canonical in autorun
    slug: Session.get 'currentPersonSlug'

Template.profile.isMine = ->
  Session.equals 'currentPersonSlug', Meteor.person()?.slug

# Publications authored by this person
Template.profile.authoredPublications = ->
  person = Persons.findOne
    slug: Session.get 'currentPersonSlug'

  Publications.find
    _id:
      $in: _.pluck person?.publications, '_id'

# Publications in logged user's library
Template.profile.myPublications = ->
  Publications.find
    _id:
      $in: _.pluck Meteor.person()?.library, '_id'

Template.profile.rendered = ->
  $(@findAll '.scrubber').iscrubber()

Handlebars.registerHelper 'currentPerson', (options) ->
  Meteor.person()

Handlebars.registerHelper 'currentPersonId', (options) ->
  Meteor.personId()
