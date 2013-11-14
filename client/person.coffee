Deps.autorun ->
  slug = Session.get 'currentPersonSlug'

  if slug
    # We also search by id because we may have to redirect to canonical URL
    Meteor.subscribe 'persons-by-id-or-slug', slug
    Meteor.subscribe 'publications-by-author-slug', slug
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
  unless slug is person.slug
    Meteor.Router.to Meteor.Router.profilePath person.slug

Template.profile.person = ->
  Persons.findOne
    # We can search by slug because we assured that the URL is canonical in autorun
    slug: Session.get 'currentPersonSlug'

Template.profile.isMine = ->
  Session.equals 'currentPersonSlug', Meteor.person()?.slug

# Publications in logged user's library
Template.profile.myPublications = ->
  Publications.find
    _id:
      $in: _.pluck Meteor.person()?.library, '_id'

Template.profile.myPublicationsImporting = ->
  Publications.find
    'importing.by.person._id': Meteor.personId()