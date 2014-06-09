# Local (client-only) document of importing files
class ImportingFile extends Document
  # name: user's file name
  # readProgress: progress of reading from file, in %
  # uploadProgress: progress of uploading file, in %
  # status: current status or error message
  # finished: true when importing has finished
  # errored: true when there was an error
  # publicationId: publication ID for the imported file
  # sha256: SHA256 hash for the file

  @Meta
    name: 'ImportingFile'
    collection: null

UPLOAD_CHUNK_SIZE = 128 * 1024 # bytes
DRAGGING_OVER_DOM = false
fileBuffer = []

# observing files with computed checksums
checksummed = ImportingFile.documents.find
  sha256:
    $exists: true
checksummed.observe
  added: (document) ->
    id = document._id
    file = fileBuffer[id].file
    fileContent = fileBuffer[id].fileContent

    console.log "Creating publication for file " + document.name
    Meteor.call 'create-publication', document.name, document.sha256, (error, result) ->
      if error
        ImportingFile.documents.update id,
          $set:
            errored: true
            status: error.toString()
        return

      if result.already
        ImportingFile.documents.update id,
          $set:
            finished: true
            status: "File already imported"
            publicationId: result.publicationId
        return

      if result.verify
        console.log "Verifying file " + document.name
        verifyFile file, fileContent, result.publicationId, result.samples
      else
        console.log "Uploading file " + document.name
        uploadFile file, result.publicationId
     
      # remove file from buffer 
      delete fileBuffer[id]

# observing files that are ready for checksum computation
preprocessed = ImportingFile.documents.find
  preprocessed:
    $exists: true
preprocessed.observe
  added: (document) ->
    id = document._id
    fileContent = fileBuffer[id].fileContent

    console.log "Computing checksum for " + document.name
    ImportingFile.documents.update id,
      $set:
        status: "Computing checksum"

    hash = new Crypto.SHA256
      onProgress: (progress) ->
        #TODO: update progressbar
    hash.update fileContent, (error, result) ->
      #TODO: handle errors
      if error
        console.log "Import error: " + error.message
    hash.finalize (error, result) ->
      #TODO: handle errors
      if error
        console.log "Import error: " + error.message

      alreadyImporting = ImportingFile.documents.findOne
        sha256: result

      if alreadyImporting
        ImportingFile.documents.update id,
          $set:
            finished: true
            status: "File is already importing"
            # publicationId might not yet be available, but let's try
            publicationId: alreadyImporting.publicationId
        return

      console.log "Setting sha256 value"
      # so that observer can do it's work
      ImportingFile.documents.update id,
        $set:
          sha256: result

verifyFile = (file, fileContent, publicationId, samples) ->
  ImportingFile.documents.update file._id,
    $set:
      status: "Verifying file"

  samplesData = _.map samples, (sample) ->
    new Uint8Array fileContent.slice sample.offset, sample.offset + sample.size
  Meteor.call 'verify-publication', publicationId, samplesData, (error) ->
    if error
      ImportingFile.documents.update file._id,
        $set:
          errored: true
          status: error.toString()
      return

    ImportingFile.documents.update file._id,
      $set:
        finished: true
        publicationId: publicationId

uploadFile = (file, publicationId) ->
  meteorFile = new MeteorFile file,
    collection: ImportingFile.Meta.collection

  meteorFile.upload file, 'upload-publication',
    size: UPLOAD_CHUNK_SIZE,
    publicationId: publicationId
  ,
    (error) ->
      if error
        ImportingFile.documents.update file._id,
          $set:
            errored: true
            status: error.toString()
        return

      ImportingFile.documents.update file._id,
        $set:
          finished: true
          publicationId: publicationId

testPDF = (file, fileContent, callback) ->
  PDFJS.getDocument(data: fileContent, password: '').then callback, (message, exception) ->
    ImportingFile.documents.update file._id,
      $set:
        errored: true
        status: "Invalid PDF file"

importFile = (file) ->
  console.log "Import file called"
  reader = new FileReader()
  reader.onload = ->
    fileContent = @result
    testPDF file, fileContent, ->
      fileBuffer[file._id] =
        file: file
        fileContent: fileContent

      ImportingFile.documents.update file._id,
        $set:
          status: "In queue for checksum computation"
          preprocessed: true

  console.log "Inserting file into collection " + file.name
  ImportingFile.documents.insert
    name: file.name
    status: "Preprocessing file"
    readProgress: 0
    uploadProgress: 0
    finished: false
    errored: false
    file: file
  ,
    # We are using callback to make sure ImportingFiles really has the file now
    (error, id) ->
      return Notify.meteorError error, true if error

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
      , 5 # ms, 0 does not seem to work, 5 seems to work

hideOverlay = ->
  allCount = ImportingFile.documents.find().count()
  finishedAndErroredCount = ImportingFile.documents.find(
    $or: [
      finished: true
    ,
      errored: true
    ]
  ).count()

  # We prevent hiding if user is uploading files
  if allCount == finishedAndErroredCount
    Session.set 'importOverlayActive', false
    ImportingFile.documents.remove {}

  Session.set 'signInOverlayActive', false

$(document).on 'dragstart', (e) ->
  # We want to prevent dragging of everything except jQuery UI controls
  return if $(e.target).is('.ui-draggable')

  e.preventDefault()

  return # Make sure CoffeeScript does not return anything

$(document).on 'dragenter', (e) ->
  e.preventDefault()

  # Don't allow importing while password reset is in progress
  return if  Accounts._loginButtonsSession.get 'resetPasswordToken'

  # For flickering issue: https://github.com/peerlibrary/peerlibrary/issues/203
  DRAGGING_OVER_DOM = true
  Meteor.setTimeout ->
    DRAGGING_OVER_DOM = false
  , 5 # ms

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

    # Replaces file input with a new version which does not have any file
    # selected. This assures that change event is triggered even if the user
    # selects the same file. It is not really reasonable to do that, but
    # it is still better that we do something than simply nothing because
    # no event is triggered.
    $(e.target, template).replaceWith($(e.target).clone())

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

    if ImportingFile.documents.find().count() == 0 and not DRAGGING_OVER_DOM
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
  $(document).off('.importOverlay').on 'keyup.importOverlay', (e) =>
    hideOverlay() if e.keyCode is 27 # Escape key
    return # Make sure CoffeeScript does not return anything

Template.importOverlay.destroyed = ->
  $(document).off '.importOverlay'

Template.importOverlay.importOverlayActive = ->
  Session.get 'importOverlayActive'

Template.importOverlay.importingFiles = ->
  ImportingFile.documents.find()

Deps.autorun ->
  importingFilesCount = ImportingFile.documents.find().count()

  return unless importingFilesCount

  finishedImportingFiles = ImportingFile.documents.find(finished: true).fetch()

  return if importingFilesCount isnt finishedImportingFiles.length

  if importingFilesCount is 1
    assert finishedImportingFiles.length is 1
    Notify.success "Imported the publication."
    Meteor.Router.toNew Meteor.Router.publicationPath finishedImportingFiles[0].publicationId
  else
    Notify.success "Imported #{ finishedImportingFiles.length } publications."
    Meteor.Router.toNew Meteor.Router.libraryPath()

  Session.set 'importOverlayActive', false

  ImportingFile.documents.remove {}
