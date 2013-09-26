Deps.autorun ->
  if Session.get 'currentPersonSlug'
    # We also search by id because we may have to redirect to canonical URL
    Meteor.subscribe 'persons-by-id-or-slug', Session.get 'currentPersonSlug'
    Meteor.subscribe 'publications-by-author-slug', Session.get 'currentPersonSlug'

Deps.autorun ->
  person = Persons.findOne()
  if person
    # Assure URL is canonical
    unless Session.equals 'currentPersonSlug', person.slug
      Meteor.Router.to Meteor.Router.profilePath person.slug
      return

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
  Publications.find()