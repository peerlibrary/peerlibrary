Deps.autorun ->
  Meteor.subscribe 'publications-importing'

Template.upload.publicationsImporting = ->
  Publications.find
    importing:
      $exists: true

Template.upload.events =
  'dragover .dropzone': (e) ->
    e.preventDefault()

  'drop .dropzone': (e) ->
    e.stopPropagation()
    e.preventDefault()

    _.each e.dataTransfer.files, (pdf) ->

      bitArray = sjcl.hash.sha256.hash pdf
      sha256 = sjcl.codec.hex.fromBits bitArray

      Meteor.call 'createPublication', pdf.name, sha256, (err, publicationId) ->
        console.log publicationId

        file = new MeteorFile pdf
        file.name = publicationId + '.pdf'
        file.upload pdf, 'uploadPublication',
          size: 128 * 1024
        , (err) ->
          if err
            throw err
          else
            Meteor.call 'finishPublicationUpload', publicationId
            console.log 'Upload successful'

  'submit form': (e) ->
    e.preventDefault()
    metadata = _.reduce $(e.target).serializeArray(), (obj, subObj) ->
      obj[subObj.name] = subObj.value
      obj
    , {}
    Meteor.call 'confirmPublication', $(e.target).data('id'), metadata