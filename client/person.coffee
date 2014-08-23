class @Person extends Person
  @Meta
    name: 'Person'
    replaceParent: true

  # We allow passing the person slug if caller knows it.
  # If you do not know if you have an ID or a slug, you can pass
  # it in as an ID and hopefully something useful will come out.
  @pathFromId = (personId, slug, options) ->
    assert _.isString personId
    # To allow calling template helper with only one argument (slug will be options then)
    slug = null unless _.isString slug

    person = @documents.findOne
      $or: [
        slug: personId
      ,
        _id: personId
      ]

    return Meteor.Router.personPath (person.slug ? slug) if person

    # Even if did not find any person document, we still prefer slug over ID
    return Meteor.Router.personPath slug if slug

    # Otherwise use ID (which is maybe a slug) and let it be resolved later
    Meteor.Router.personPath personId

  path: ->
    @constructor.pathFromId @_id, @slug

  # Helper object with properties useful to refer to this document. Optional person document.
  # If you do not know if you have an ID or a slug, you can pass it in as an ID and hopefully
  # something useful will come out.
  @reference: (personId, person, options) ->
    assert _.isString personId
    # To allow calling template helper with only one argument (person will be options then)
    person = null unless person instanceof @

    unless person
      person = @documents.findOne
        $or: [
          slug: personId
        ,
          _id: personId
        ]
    assert personId, person._id if person

    if person
      _id: personId # TODO: Remove when we will be able to access parent template context
      text: "@#{ person.slug }"
      title: person.getDisplayName()
    else
      _id: personId # TODO: Remove when we will be able to access parent template context
      text: "@#{ personId }"

  reference: ->
    @constructor.reference @_id, @

Deps.autorun ->
  slug = Session.get 'currentPersonSlug'

  if slug
    # We also search by id because we may have to redirect to canonical URL
    Meteor.subscribe 'persons-by-ids-or-slugs', slug
    Meteor.subscribe 'publications-by-author-slug', slug

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

# Publications authored by this person
Template.person.authoredPublications = ->
  person = Person.documents.findOne
    # We can search by only slug because we assured that the URL is canonical in autorun
    slug: Session.get 'currentPersonSlug'

  Publication.documents.find
    _id:
      $in: _.pluck person?.publications, '_id'

Handlebars.registerHelper 'currentPerson', (options) ->
  Meteor.person()

Handlebars.registerHelper 'currentPersonId', (options) ->
  Meteor.personId()

Handlebars.registerHelper 'personPathFromId', _.bind Person.pathFromId, Person

Handlebars.registerHelper 'personReference', _.bind Person.reference, Person
