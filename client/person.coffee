Deps.autorun ->
  slug = Session.get 'currentPersonSlug'

  if slug
    # We also search by id because we may have to redirect to canonical URL
    Meteor.subscribe 'persons-by-id-or-slug', slug
    Meteor.subscribe 'publications-by-author-slug', slug

Deps.autorun ->
  slug = Session.get 'currentPersonSlug'

  person = Person.documents.findOne
    $or: [
      slug: slug
    ,
      _id: slug
    ]

  return unless person

  # Assure URL is canonical
  Meteor.Router.toNew Meteor.Router.profilePath person.slug unless slug is person.slug

Template.profile.person = ->
  Person.documents.findOne
    # We can search by slug because we assured that the URL is canonical in autorun
    slug: Session.get 'currentPersonSlug'

Template.profile.isMine = ->
  Session.equals 'currentPersonSlug', Meteor.person()?.slug

# Publications authored by this person
Template.profile.authoredPublications = ->
  person = Person.documents.findOne
    slug: Session.get 'currentPersonSlug'

  Publication.documents.find
    _id:
      $in: _.pluck person?.publications, '_id'

# Publications in logged user's library
Template.library.myPublications = ->
  Publication.documents.find
    _id:
      $in: _.pluck Meteor.person()?.library, '_id'

Handlebars.registerHelper 'currentPerson', (options) ->
  Meteor.person()

Handlebars.registerHelper 'currentPersonId', (options) ->
  Meteor.personId()
