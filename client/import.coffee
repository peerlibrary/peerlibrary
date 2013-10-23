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
        hash = new Crypto.SHA256()
        hash.update this.result
        sha256 = hash.finalize()

        Meteor.call 'createPublication', file.name, sha256, (err, publicationId) ->
          throw err if err

          # It already existed and was added to library
          unless publicationId
            Session.set 'uploadOverlayActive', false
            Meteor.Router.to '/u/' + Meteor.person()?.slug
            return

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
                Meteor.Router.to '/u/' + Meteor.person()?.slug

      reader.readAsArrayBuffer file

  'click': (e, template) ->
    Session.set 'uploadOverlayActive', false

Template.uploadOverlay.uploadOverlayActive = ->
  Session.get 'uploadOverlayActive'

Template.uploadOverlay.publicationsUploading = ->
  Publications.find
    'importing.by._id': Meteor.userId()
    'importing.uploadProgress':
      $lt: 1

Template.uploadProgressBar.progress = ->
  100 * @importing.uploadProgress

Template.publicationImporting.progress = ->
  50 * @importing.uploadProgress + 50 * @importing.processProgress

Template.importPublicationForm.events =
  'submit form': (e) ->
    e.preventDefault()
    metadata = _.reduce $(e.target).serializeArray(), (obj, subObj) ->
      obj[subObj.name] = subObj.value
      obj
    , {}
    Meteor.call 'confirmPublication', $(e.target).data('id'), metadata