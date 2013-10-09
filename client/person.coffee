Deps.autorun ->
  slug = Session.get 'currentPersonSlug'

  if slug
    # We also search by id because we may have to redirect to canonical URL
    Meteor.subscribe 'persons-by-id-or-slug', slug
    Meteor.subscribe 'publications-by-author-slug', slug
    # TODO: resubscribe after importing
    if Meteor.user()
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
  person = Persons.findOne
    slug: Session.get 'currentPersonSlug'

  return unless person

  person.user.id == Meteor.user()?._id

# Publications in logged user's library
Template.profile.myPublications = ->
  person = Persons.findOne
    slug: Session.get 'currentPersonSlug'
    'user.id': Meteor.user()?._id

  return unless person

  Publications.find
    _id:
      $in: person.library or []
    importing:
      $exists: false

Template.profile.myPublicationsImporting = ->
  person = Persons.findOne
    slug: Session.get 'currentPersonSlug'
    'user.id': Meteor.user()?._id

  return unless person

  Publications.find
    'importing.by.id': Meteor.user()?._id

Template.profile.events =
  'dragover .dropzone': (e) ->
    e.preventDefault()

  'drop .dropzone': (e) ->
    e.stopPropagation()
    e.preventDefault()

    _.each e.dataTransfer.files, (file) ->

      reader = new FileReader()
      reader.onload = ->
        hash = new Crypto.SHA256()
        hash.update this.result
        sha256 = hash.finalize()

        Meteor.call 'createPublication', file.name, sha256, (err, publicationId) ->
          throw err if err
          console.log publicationId
          meteorFile = new MeteorFile file
          meteorFile.name = publicationId + '.pdf'
          meteorFile.upload file, 'uploadPublication',
            size: 128 * 1024
          , (err) ->
            throw err if err

            Meteor.call 'finishPublicationUpload', publicationId, (err) ->
              throw err if err
              console.log 'Upload successful'

      reader.readAsArrayBuffer file

  'submit form': (e) ->
    e.preventDefault()
    metadata = _.reduce $(e.target).serializeArray(), (obj, subObj) ->
      obj[subObj.name] = subObj.value
      obj
    , {}
    Meteor.call 'confirmPublication', $(e.target).data('id'), metadata

Template.publicationImporting.progress = ->
  50 * @importing.uploadProgress + 50 * @importing.processProgress
