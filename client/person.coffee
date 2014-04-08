Deps.autorun ->
  slug = Session.get 'currentPersonSlug'

  if slug
    # We also search by id because we may have to redirect to canonical URL
    Meteor.subscribe 'persons-by-id-or-slug', slug
    Meteor.subscribe 'publications-by-author-slug', slug

    if slug is Meteor.person()?.slug
      Meteor.subscribe 'my-publications'
      # TODO: Display also publications which are currently being imported? Publications which have not been completed? Should canceling the import then not just stop importing, but also remove it from this list? Or should it stay in the list and should we require additional action to really remove it?
      #Meteor.subscribe 'my-publications-importing'

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
Template.profile.myPublications = ->
  Publication.documents.find
    _id:
      $in: _.pluck Meteor.person()?.library, '_id'

Handlebars.registerHelper 'currentPerson', (options) ->
  Meteor.person()

Handlebars.registerHelper 'currentPersonId', (options) ->
  Meteor.personId()
