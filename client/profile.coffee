Deps.autorun ->
  if Session.get 'currentPersonSlug'
    Meteor.subscribe 'persons-by-slug', Session.get 'currentPersonSlug'
    Meteor.subscribe 'publications-by-author-slug', Session.get 'currentPersonSlug'

Deps.autorun ->
  person = Persons.findOne()
  if person
    unless Session.equals 'currentPersonSlug', person.slug
      Meteor.Router.to Meteor.Router.profilePath person.slug
      return

Template.profile.person = ->
  Persons.findOne
    # We can search by slug because we assured that the URL is canonical in autorun
    slug: Session.get 'currentPersonSlug'

Template.profile.publications = ->
  Publications.find()