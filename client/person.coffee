Deps.autorun ->
  slug = Session.get 'currentPersonSlug'

  if slug
    # We also search by id because we may have to redirect to canonical URL
    Meteor.subscribe 'persons-by-id-or-slug', slug
    Meteor.subscribe 'publications-by-author-slug', slug

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
  unless slug is person.slug
    Meteor.Router.to Meteor.Router.profilePath person.slug

Template.profile.person = ->
  Persons.findOne
    # We can search by slug because we assured that the URL is canonical in autorun
    slug: Session.get 'currentPersonSlug'

Template.profile.isMine = ->
  person = Persons.findOne
    slug: Session.get 'currentPersonSlug'
  if person
    person.user.id == Meteor.user()._id

Template.profile.publications = ->
  # TODO: This should not be returning all publications, but only those relevant to the profile
  Publications.find()