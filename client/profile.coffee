Deps.autorun ->
  if Session.get 'currentPersonSlug'
    Meteor.subscribe 'persons-by-slug', Session.get 'currentPersonSlug'
    Meteor.subscribe 'publications-by-author-slug', Session.get 'currentPersonSlug'

Template.profile.person = ->
  Persons.findOne
    slug: Session.get 'currentPersonSlug'

Template.profile.publications = ->
  Publications.find()