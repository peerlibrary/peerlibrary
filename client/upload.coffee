Deps.autorun ->
  # TODO: resubscribe after importing
  if Session.equals 'uploadActive', true
    Meteor.subscribe 'my-publications'
    Meteor.subscribe 'my-publications-importing'

Template.upload.publicationsImporting = ->
  Publications.find
    importing:
      $exists: true

Template.upload.publicationsInLibrary = ->
  person = Persons.findOne
    'user.id': Meteor.user()?._id

  return unless person

  Publications.find
    _id:
      $in: person.library or []
    importing:
      $exists: false

Template.upload.events =
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
          if err
            throw err
          else
            console.log publicationId 
            meteorFile = new MeteorFile file
            meteorFile.name = publicationId + '.pdf'
            meteorFile.upload file, 'uploadPublication',
              size: 128 * 1024
            , (err) ->
              if err
                throw err
              else
                Meteor.call 'finishPublicationUpload', publicationId
                console.log 'Upload successful'

      reader.readAsArrayBuffer file


  'submit form': (e) ->
    e.preventDefault()
    metadata = _.reduce $(e.target).serializeArray(), (obj, subObj) ->
      obj[subObj.name] = subObj.value
      obj
    , {}
    Meteor.call 'confirmPublication', $(e.target).data('id'), metadata