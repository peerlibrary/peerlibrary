Deps.autorun ->
  if Session.equals 'uploadOverlayActive', true
    Meteor.subscribe 'my-publications-importing'

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
          meteorFile = new MeteorFile file
          meteorFile.name = publicationId + '.pdf'
          meteorFile.upload file, 'uploadPublication',
            size: 128 * 1024
          , (err) ->
            throw err if err

            Meteor.call 'finishPublicationUpload', publicationId, (err) ->
              throw err if err
              if Publications.find(
                'importing.uploadProgress':
                  $lt: 1
              ).count() == 0
                Session.set 'uploadOverlayActive', false
              console.log 'Upload successful'

      reader.readAsArrayBuffer file

  'click': (e, template) ->
    Session.set 'uploadOverlayActive', false

Template.uploadOverlay.uploadOverlayActive = ->
  Session.get 'uploadOverlayActive'

Template.uploadOverlay.publicationsUploading = ->
  Publications.find
    'importing.uploadProgress':
      $lt: 1

Template.uploadProgressBar.progress = ->
  100 * @importing.uploadProgress