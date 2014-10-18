class @Person extends Person
  @Meta
    name: 'Person'
    replaceParent: true

  # We allow passing the person slug if caller knows it.
  # If you do not know if you have an ID or a slug, you can pass
  # it in as an ID and hopefully something useful will come out.
  @pathFromId = (personId, slug) ->
    assert _.isString personId

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

  path: =>
    @constructor.pathFromId @_id, @slug

  route: =>
    source: @constructor.verboseName()
    route: 'person'
    params:
      personSlug: @slug

  # Helper object with properties useful to refer to this document. Optional person document.
  # If you do not know if you have an ID or a slug, you can pass it in as an ID and hopefully
  # something useful will come out.
  @reference: (personId, person) ->
    assert _.isString personId

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

  reference: =>
    @constructor.reference @_id, @

Tracker.autorun ->
  slug = Session.get 'currentPersonSlug'

  return unless slug

  # We also search by id because we may have to redirect to canonical URL
  Meteor.subscribe 'persons-by-ids-or-slugs', slug
  Meteor.subscribe 'publications-by-author-slug', slug

Tracker.autorun ->
  slug = Session.get 'currentPersonSlug'

  return unless slug

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

Template.person.helpers
  person: ->
    Person.documents.findOne
      # We can search by only slug because we assured that the URL is canonical in autorun
      slug: Session.get 'currentPersonSlug'

  # Publications authored by this person
  authoredPublications: ->
    person = Person.documents.findOne
      # We can search by only slug because we assured that the URL is canonical in autorun
      slug: Session.get 'currentPersonSlug'

    Publication.documents.find
      _id:
        $in: _.pluck person?.publications, '_id'

Template.registerHelper 'currentPerson', ->
  Meteor.person()

Template.registerHelper 'currentPersonId', ->
  Meteor.personId()

Template.registerHelper 'isPerson', ->
  @ instanceof Person

Template.registerHelper 'personPathFromId', _.bind Person.pathFromId, Person

Template.registerHelper 'personReference', _.bind Person.reference, Person
