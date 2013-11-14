UPLOAD_CHUNK_SIZE = 128 * 1024 # bytes

Deps.autorun ->
  if Session.equals 'uploadOverlayActive', true
    Meteor.subscribe 'my-publications-importing'

Meteor.startup ->
  $(document).on 'dragenter', (e) ->
    e.preventDefault()

    if Meteor.user()
      Session.set 'uploadOverlayActive', true
    else
      Session.set 'loginOverlayActive', true

Template.loginOverlay.loginOverlayActive = ->
  Session.get 'loginOverlayActive'

Template.loginOverlay.events =
  'dragover': (e, template) ->
    e.preventDefault()

  'drop': (e, template) ->
    e.stopPropagation()
    e.preventDefault()
    Session.set 'loginOverlayActive', false

Template.uploadOverlay.created = ->
  @_amountOfImports = 0

Template.uploadOverlay.events =
  'dragover': (e, template) ->
    e.preventDefault()

  'drop': (e, template) ->
    e.stopPropagation()
    e.preventDefault()

    unless Meteor.user()
      Session.set 'uploadOverlayActive', false
      return

    _.each e.dataTransfer.files, (file) ->

      reader = new FileReader()
      reader.onload = ->
        # TODO: Compute SHA in chunks
        hash = new Crypto.SHA256()
        hash.update @result
        sha256 = hash.finalize()

        Meteor.call 'createPublication', file.name, sha256, (err, result) ->
          throw err if err

          if result.verify
            samplesData = _.map result.samples, (sample) ->
              return new Uint8Array reader.result.slice sample.offset, sample.offset + sample.size
            Meteor.call 'verifyPublication', result.publicationId, samplesData, (err, success) ->
              if success
                Meteor.Router.to '/p/' + result.publicationId
              else
                Session.set 'loginOverlayActive', false # TODO: Display error?
          else
            template._amountOfImports += 1
            meteorFile = new MeteorFile file
            # TODO: Use meteorFile.options instead of name
            meteorFile.name = result.publicationId
            meteorFile.upload file, 'uploadPublication',
              size: UPLOAD_CHUNK_SIZE,
              publicationId: result.publicationId
            , (err) ->
              throw err if err

              if Publications.find(
                'importing.by.person._id': Meteor.personId()
                cached: false
              ).count() == 0
                if template._amountOfImports > 1
                  Meteor.Router.to '/u/' + Meteor.personId()
                else
                  Meteor.Router.to '/p/' + result.publicationId

                template._amountOfImports = 0

      reader.readAsArrayBuffer file

  'click': (e, template) ->
    Session.set 'uploadOverlayActive', false

Template.uploadOverlay.uploadOverlayActive = ->
  Session.get 'uploadOverlayActive'

Template.uploadOverlay.publicationsUploading = ->
  Publications.find
    'importing.by.person._id': Meteor.personId()
    cached: false

Template.uploadProgressBar.progress = ->
  100 * @importing.by[0].uploadProgress

Template.publicationLibraryItem.filename = ->
  @importing.by[0].filename

# TODO: Clean or integrate this with publication view
Template.importPublicationForm.events =
  'submit form': (e) ->
    e.preventDefault()
    metadata = _.reduce $(e.target).serializeArray(), (obj, subObj) ->
      obj[subObj.name] = subObj.value
      obj
    , {}
    Meteor.call 'confirmPublication', $(e.target).data('id'), metadata