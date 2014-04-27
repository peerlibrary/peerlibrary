Deps.autorun ->
  slug = Session.get 'currentPersonSlug'

  if slug
    # We also search by id because we may have to redirect to canonical URL
    Meteor.subscribe 'persons-by-id-or-slug', slug
    Meteor.subscribe 'publications-by-author-slug', slug

    if slug is Meteor.person()?.slug
      Meteor.subscribe 'my-publications'
      # So that users can see their own filename of the imported file, before a publication has metadata
      Meteor.subscribe 'my-publications-importing'

Deps.autorun ->
  slug = Session.get 'currentPersonSlug'

  person = Person.documents.findOne
    $or: [
      slug: slug
    ,
      _id: slug
    ]
  ,
    fields:
      slug: 1

  return unless person

  # Assure URL is canonical
  Meteor.Router.toNew Meteor.Router.personPath person.slug unless slug is person.slug

Template.person.person = ->
  Person.documents.findOne
    # We can search by only slug because we assured that the URL is canonical in autorun
    slug: Session.get 'currentPersonSlug'

Template.person.isMine = ->
  # TODO: This is not a permission check, should check if you have permissions if this is what is wanted
  Session.equals 'currentPersonSlug', Meteor.person()?.slug

# Publications authored by this person
Template.person.authoredPublications = ->
  person = Person.documents.findOne
    # We can search by only slug because we assured that the URL is canonical in autorun
    slug: Session.get 'currentPersonSlug'

  Publication.documents.find
    _id:
      $in: _.pluck person?.publications, '_id'

# Publications in logged user's library
Template.person.myPublications = ->
  Publication.documents.find
    _id:
      $in: _.pluck Meteor.person()?.library, '_id'

Handlebars.registerHelper 'currentPerson', (options) ->
  Meteor.person()

Handlebars.registerHelper 'currentPersonId', (options) ->
  Meteor.personId()

# We allow passing the person slug if caller knows it.
# If you do not know if you have an ID or a slug, you can pass
# it in as an ID and hopefully something useful will come out.
Handlebars.registerHelper 'personPathFromId', (personId, slug, options) ->
  person = Person.documents.findOne
    $or: [
      slug: personId
    ,
      _id: personId
    ]

  return Meteor.Router.personPath person.slug if person

  # Even if did not find any person document, we still prefer slug over ID
  return Meteor.Router.personPath slug if slug

  # Otherwise use ID (which is maybe a slug) and let it be resolved later
  Meteor.Router.personPath personId
