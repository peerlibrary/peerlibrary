Deps.autorun ->
  if Session.get 'currentPersonSlug'
    # We also search by id because we may have to redirect to canonical URL
    Meteor.subscribe 'persons-by-id-or-slug', Session.get 'currentPersonSlug'
    Meteor.subscribe 'publications-by-author-slug', Session.get 'currentPersonSlug'

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

Template.profile.publications = ->
  Publications.find()