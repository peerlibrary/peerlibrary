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

    _.each e.dataTransfer.files, (file) ->

      reader = new FileReader()
      reader.onload = ->
        bitArray = sjcl.hash.sha256.hash sjcl.codec.arrayBuffer.toBits this.result
        sha256 = sjcl.codec.hex.fromBits bitArray
        # console.log sha256

        Meteor.call 'createPublication', file.name, sha256, (err, publicationId) ->
          if err
            throw err
          else
            # console.log publicationId 
            meteorFile = new MeteorFile file
            meteorFile.name = publicationId + '.pdf'
            meteorFile.upload file, 'uploadPublication',
              size: 128 * 1024
            , (err) ->
              if err
                throw err
              else
                Meteor.call 'finishPublicationUpload', publicationId
                # console.log 'Upload successful'

      reader.readAsArrayBuffer file


  'submit form': (e) ->
    e.preventDefault()
    metadata = _.reduce $(e.target).serializeArray(), (obj, subObj) ->
      obj[subObj.name] = subObj.value
      obj
    , {}
    Meteor.call 'confirmPublication', $(e.target).data('id'), metadata