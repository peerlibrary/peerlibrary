Deps.autorun ->

  Template.upload.events =
    'change input': (e) ->
      _.each e.srcElement.files, (pdf) ->

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
