# Local (client-only) collection of importing files
# Fields:
#   name: user's file name
#   readProgress: progress of reading from file, in %
#   uploadProgress: progress of uploading file, in %
#   status: current status or error message
#   finished: true when importing has finished
#   publicationId: publication ID for the imported file
#   sha256: SHA256 hash for the file
ImportingFiles = new Meteor.Collection null

UPLOAD_CHUNK_SIZE = 128 * 1024 # bytes

verifyFile = (file, fileContent, publicationId, samples) ->
  samplesData = _.map samples, (sample) ->
    new Uint8Array fileContent.slice sample.offset, sample.offset + sample.size
  Meteor.call 'verifyPublication', publicationId, samplesData, (err) ->
    if err
      ImportingFiles.update file._id,
        $set:
          status: err.toString()
      return

    ImportingFiles.update file._id,
      $set:
        finished: true
        publicationId: publicationId

uploadFile = (file, publicationId) ->
  meteorFile = new MeteorFile file,
    collection: ImportingFiles

  meteorFile.upload file, 'uploadPublication',
    size: UPLOAD_CHUNK_SIZE,
    publicationId: publicationId
  ,
    (err) ->
      if err
        ImportingFiles.update file._id,
          $set:
            status: err.toString()
        return

      ImportingFiles.update file._id,
        $set:
          finished: true
          publicationId: publicationId

testPDF = (file, fileContent, callback) ->
  PDFJS.getDocument(data: fileContent, password: '').then callback, (message, exception) ->
    ImportingFiles.update file._id,
      $set:
        status: "Invalid file: #{ exception or message }"

importFile = (file) ->
  reader = new FileReader()
  reader.onload = ->
    fileContent = @result

    testPDF file, fileContent, ->
      # TODO: Compute SHA in chunks
      # TODO: Compute SHA in a web worker?
      hash = new Crypto.SHA256()
      hash.update fileContent
      sha256 = hash.finalize()

      alreadyImporting = ImportingFiles.findOne(sha256: sha256)
      if alreadyImporting
        ImportingFiles.update file._id,
          $set:
            status: "File is already importing"
            finished: true
            # publicationId might not yet be available, but let's try
            publicationId: alreadyImporting.publicationId
        return

      ImportingFiles.update file._id,
        $set:
          sha256: sha256

      Meteor.call 'createPublication', file.name, sha256, (err, result) ->
        if err
          ImportingFiles.update file._id,
            $set:
              status: err.toString()
          return

        if result.already
          ImportingFiles.update file._id,
            $set:
              status: "File already imported"
              finished: true
              publicationId: result.publicationId
          return

        if result.verify
          verifyFile file, fileContent, result.publicationId, result.samples
        else
          uploadFile file, result.publicationId

  ImportingFiles.insert
    name: file.name
    status: "Preprocessing file"
    readProgress: 0
    uploadProgress: 0
    finished: false
  ,
    # We are using callback to make sure ImportingFiles really has the file now
    (err, id) ->
      throw err if err

      # So that meteor-file knows what to update
      file._id = id

      # We try to make sure list of files is rendered before hashing
      Deps.flush()

      # Just temporary return to the event thread so that everything finishes rendering
      Meteor.setTimeout ->
        # TODO: We should read in chunks, not whole file
        reader.readAsArrayBuffer file
      , 5 # 0 does not seem to work, 5 seems to work

Meteor.startup ->
  $(document).on 'dragenter', (e) ->
    e.preventDefault()

    if Meteor.personId()
      Session.set 'importOverlayActive', true
    else
      Session.set 'loginOverlayActive', true

Template.loginOverlay.loginOverlayActive = ->
  Session.get 'loginOverlayActive'

Template.loginOverlay.events =
  'dragover': (e, template) ->
    e.preventDefault()

  'dragleave': (e, template) ->
    e.preventDefault()
    Session.set 'loginOverlayActive', false

  'drop': (e, template) ->
    e.stopPropagation()
    e.preventDefault()
    Session.set 'loginOverlayActive', false

Template.importOverlay.events =
  'dragover': (e, template) ->
    e.preventDefault()

  'dragleave': (e, template) ->
    e.preventDefault()

    if ImportingFiles.find().count() == 0
      Session.set 'importOverlayActive', false

  'drop': (e, template) ->
    e.stopPropagation()
    e.preventDefault()

    unless Meteor.personId()
      Session.set 'importOverlayActive', false
      return

    _.each e.dataTransfer.files, importFile

  'click': (e, template) ->
    # We hide overlay, but in the background we are still uploading
    # TODO: Should we allow some way to bring the overlay back in front?
    Session.set 'importOverlayActive', false

Template.importOverlay.importOverlayActive = ->
  Session.get 'importOverlayActive'

Template.importOverlay.importingFiles = ->
  ImportingFiles.find()

Deps.autorun ->
  importingFilesCount = ImportingFiles.find().count()

  return unless importingFilesCount

  finishedImportingFiles = ImportingFiles.find(finished: true).fetch()

  return if importingFilesCount isnt finishedImportingFiles.length

  # We want to redirect only when overlay is active
  if Session.get 'importOverlayActive'
    if importingFilesCount is 1
      assert finishedImportingFiles.length is 1
      Meteor.Router.to Meteor.Router.publicationPath finishedImportingFiles[0].publicationId
    else
      Meteor.Router.to Meteor.Router.profilePath Meteor.personId()
    Session.set 'importOverlayActive', false

  ImportingFiles.remove({})
