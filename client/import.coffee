Deps.autorun ->
  publication = Session.get 'uploadingPublicationId'

  if publication
    Meteor.subscribe 'publications-by-id', publication

Meteor.startup ->
  $(document).on 'dragenter', (e) ->
    e.preventDefault()
    Session.set 'uploadOverlayActive', true

Template.uploadOverlay.events =
  'dragover': (e, template) ->
    e.preventDefault()

  'drop': (e, template) ->
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
          Session.set 'uploadingPublicationId', publicationId
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

  'click': (e, template) ->
    Session.set 'uploadOverlayActive', false

Template.uploadOverlay.uploadOverlayActive = ->
  Session.get 'uploadOverlayActive'

Template.uploadOverlay.publicationUploading = ->
  Publications.findOne
    _id: Session.get 'uploadingPublicationId'

Template.uploadProgressBar.progress = ->
  100 * @importing.uploadProgress