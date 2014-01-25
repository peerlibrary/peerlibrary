# Local (client-only) collection of importing files
# Fields:
#   name: user's file name
#   readProgress: progress of reading from file, in %
#   uploadProgress: progress of uploading file, in %
#   status: current status or error message
#   finished: true when importing has finished
#   errored: true when there was an error
#   publicationId: publication ID for the imported file
#   sha256: SHA256 hash for the file
ImportingFiles = new Meteor.Collection null

UPLOAD_CHUNK_SIZE = 128 * 1024 # bytes
DRAGGING_OVER_DOM = false

verifyFile = (file, fileContent, publicationId, samples) ->
  ImportingFiles.update file._id,
    $set:
      status: "Verifying file"

  samplesData = _.map samples, (sample) ->
    new Uint8Array fileContent.slice sample.offset, sample.offset + sample.size
  Meteor.call 'verifyPublication', publicationId, samplesData, (error) ->
    if error
      ImportingFiles.update file._id,
        $set:
          errored: true
          status: error.toString()
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
    (error) ->
      if error
        ImportingFiles.update file._id,
          $set:
            errored: true
            status: error.toString()
        return

      ImportingFiles.update file._id,
        $set:
          finished: true
          publicationId: publicationId

testPDF = (file, fileContent, callback) ->
  PDFJS.getDocument(data: fileContent, password: '').then callback, (message, exception) ->
    ImportingFiles.update file._id,
      $set:
        errored: true
        status: "Invalid PDF file"

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
            finished: true
            status: "File is already importing"
            # publicationId might not yet be available, but let's try
            publicationId: alreadyImporting.publicationId
        return

      ImportingFiles.update file._id,
        $set:
          sha256: sha256

      Meteor.call 'createPublication', file.name, sha256, (error, result) ->
        if error
          ImportingFiles.update file._id,
            $set:
              errored: true
              status: error.toString()
          return

        if result.already
          ImportingFiles.update file._id,
            $set:
              finished: true
              status: "File already imported"
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
    errored: false
  ,
    # We are using callback to make sure ImportingFiles really has the file now
    (error, id) ->
      throw error if error

      # So that meteor-file knows what to update
      file._id = id

      # We make sure list of files is rendered before hashing
      Deps.flush()

      # TODO: Remove the following workaround for a bug
      # Deps.flush does not seem to really do it, so we have to use Meteor.setTimeout to workaround
      # See: https://github.com/meteor/meteor/issues/1619
      Meteor.setTimeout ->
        # TODO: We should read in chunks, not whole file
        reader.readAsArrayBuffer file
      , 5 # 0 does not seem to work, 5 seems to work

hideOverlay = ->
  allCount = ImportingFiles.find().count()
  finishedAndErroredCount = ImportingFiles.find(
    $or: [
      finished: true
    ,
      errored: true
    ]
  ).count()
  # We prevent hiding if user is uploading files
  Session.set 'importOverlayActive', false if allCount == finishedAndErroredCount
  ImportingFiles.remove({})

Meteor.startup ->
  $(document).on 'dragstart', (e) ->
    # We want to prevent dragging of everything except the viewport
    return if $(e.target).is('.viewport')

    e.preventDefault()

    return # Make sure CoffeeScript does not return anything

  $(document).on 'dragenter', (e) ->
    e.preventDefault()

    # For flickering issue: https://github.com/peerlibrary/peerlibrary/issues/203
    DRAGGING_OVER_DOM = true
    Meteor.setTimeout ->
      DRAGGING_OVER_DOM = false
    , 5

    if Meteor.personId()
      Session.set 'importOverlayActive', true
      e.originalEvent.dataTransfer.effectAllowed = 'copy'
      e.originalEvent.dataTransfer.dropEffect = 'copy'
    else
      Session.set 'signInOverlayActive', true
      e.originalEvent.dataTransfer.effectAllowed = 'none'
      e.originalEvent.dataTransfer.dropEffect = 'none'

    return # Make sure CoffeeScript does not return anything

Template.importButton.events =
  'click .import': (e, template) ->
    e.preventDefault()

    if Meteor.personId()
      $(template.findAll '.import-file-input').click()
    else
      Session.set 'signInOverlayActive', true

    return # Make sure CoffeeScript does not return anything

  'change input.import-file-input': (e, template) ->
    e.preventDefault()

    return if e.target.files?.length is 0

    Session.set 'importOverlayActive', true
    _.each e.target.files, importFile

    return # Make sure CoffeeScript does not return anything

Template.searchInput.events =
  'click .drop-files-to-import': (e, template) ->
    e.preventDefault()

    $('ul.top-menu .import').click()

Template.signInOverlay.signInOverlayActive = ->
  Session.get 'signInOverlayActive'

Template.signInOverlay.events =
  'dragover': (e, template) ->
    e.preventDefault()
    e.dataTransfer.effectAllowed = 'none'
    e.dataTransfer.dropEffect = 'none'

    return # Make sure CoffeeScript does not return anything

  'dragleave': (e, template) ->
    e.preventDefault()

    unless DRAGGING_OVER_DOM
      Session.set 'signInOverlayActive', false

    return # Make sure CoffeeScript does not return anything

  'drop': (e, template) ->
    e.stopPropagation()
    e.preventDefault()
    Session.set 'signInOverlayActive', false

    return # Make sure CoffeeScript does not return anything

  'click': (e, template) ->
    e.preventDefault()
    Session.set 'signInOverlayActive', false

    return # Make sure CoffeeScript does not return anything

Template.importOverlay.events =
  'dragover': (e, template) ->
    e.preventDefault()
    e.dataTransfer.effectAllowed = 'copy'
    e.dataTransfer.dropEffect = 'copy'

    return # Make sure CoffeeScript does not return anything

  'dragleave': (e, template) ->
    e.preventDefault()

    if ImportingFiles.find().count() == 0 and not DRAGGING_OVER_DOM
      Session.set 'importOverlayActive', false

    return # Make sure CoffeeScript does not return anything

  'drop': (e, template) ->
    e.stopPropagation()
    e.preventDefault()

    unless Meteor.personId()
      Session.set 'importOverlayActive', false
      return

    _.each e.dataTransfer.files, importFile

    return # Make sure CoffeeScript does not return anything

  'click': (e, template) ->
    hideOverlay()

    return # Make sure CoffeeScript does not return anything

Template.importOverlay.rendered = ->
  $(document).on 'keyup.importOverlay', (e) ->
    hideOverlay() if e.keyCode is 27 # esc key
    return # Make sure CoffeeScript does not return anything

Template.importOverlay.destroyed = ->
  $(document).off 'keyup.importOverlay'

Template.importOverlay.importOverlayActive = ->
  Session.get 'importOverlayActive'

Template.importOverlay.importingFiles = ->
  ImportingFiles.find()

Deps.autorun ->
  importingFilesCount = ImportingFiles.find().count()

  return unless importingFilesCount

  finishedImportingFiles = ImportingFiles.find(finished: true).fetch()

  return if importingFilesCount isnt finishedImportingFiles.length

  if importingFilesCount is 1
    assert finishedImportingFiles.length is 1
    Meteor.Router.toNew Meteor.Router.publicationPath finishedImportingFiles[0].publicationId
  else
    Meteor.Router.toNew Meteor.Router.profilePath Meteor.personId()

  Session.set 'importOverlayActive', false

  ImportingFiles.remove({})
