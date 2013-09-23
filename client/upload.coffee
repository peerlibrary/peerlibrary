Template.uploadForm.events =
  'dragover .dropzone': (e) ->
    e.preventDefault()

  'drop .dropzone': (e) ->
    e.stopPropagation()
    e.preventDefault()

    _.each e.dataTransfer.files, (pdf) ->

      Meteor.call 'createPublication', (err, publicationId) ->
        file = new MeteorFile pdf
        file.name = publicationId + '.pdf'

        file.upload pdf, 'uploadPublication',
          size: 128 * 1024
        , (err) ->
          if err
            throw err
          else
            Meteor.call 'confirmPublicationUpload', publicationId
            console.log 'Upload successful'