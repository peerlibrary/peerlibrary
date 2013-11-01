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

          meteorFile = new MeteorFile file
          # TODO: Fix this hack
          meteorFile.name = publicationId
          meteorFile.upload file, 'uploadPublication',
            size: 128 * 1024,
            publicationId: publicationId
          , (err) ->
            throw err if err

            if Publications.find(
              'importing.uploadProgress':
                $lt: 1
            ).count() == 0
              Meteor.Router.to '/p/' + publicationId

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
  100 * @importing.uploadProgress

Template.importPublicationForm.events =
  'submit form': (e) ->
    e.preventDefault()
    metadata = _.reduce $(e.target).serializeArray(), (obj, subObj) ->
      obj[subObj.name] = subObj.value
      obj
    , {}
    Meteor.call 'confirmPublication', $(e.target).data('id'), metadata