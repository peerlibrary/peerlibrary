# Local (client-only) document of importing files
class @ImportingFile extends BaseDocument
  # name: user's file name
  # status: current status or error message displayed to user
  # readProgress: progress of reading from file, in %
  # uploadProgress: progress of uploading file, in %
  # preprocessingProgress: progress of file preprocessing, in %
  # canceled: true when user cancels import
  # publicationId: publication ID for the imported file
  # sha256: SHA256 hash for the file
  # state: current document state, one of the following constant strings
  #   new: file in queue for preprocessing
  #   preprocessing: file currently being preprocessed
  #   preprocessed: file in queue for importing
  #   importing: file currently being imported
  #   finished: file processing finished successfully, but it
  #             was not imported (import canceled or already exists)
  #   imported: file processing finished successfully and it was imported
  #   errored: file processing errored

  @Meta
    name: 'ImportingFile'
    collection: null

UPLOAD_CHUNK_SIZE = 128 * 1024 # bytes

draggingOverDom = false
importingFiles = {}

# Observes files that are processed and removes them from dictionary
processedFiles = ImportingFile.documents.find {}
processedFiles.observeChanges
  removed: (id) ->
    delete importingFiles[id]

# Observes files that get canceled while being in preprocessing or import queue
canceledFiles = ImportingFile.documents.find
  canceled: true
  state:
    $in: ['new', 'preprocessed']
canceledFiles.observeChanges
  added: (id) ->
    ImportingFile.documents.update
      _id: id
      canceled: true
      state:
        $in: ['new', 'preprocessed']
    ,
      $set:
        state: 'finished'
        status: "Import canceled"

publicationHandles = {}

# Subscribe to publications that have been matched on the server
Tracker.autorun ->
  ImportingFile.documents.find({publicationId: $exists: true}, {fields: publicationId: 1}).forEach (file) ->
    Meteor.subscribe 'publication-by-id', file.publicationId

verifyFile = (file, publicationId, samples) ->
  ImportingFile.documents.update file._id,
    $set:
      status: "Verifying file"

  samplesData = for sample in samples
    new Uint8Array file.content.slice sample.offset, sample.offset + sample.size
  Meteor.call 'verify-publication', publicationId, samplesData, (error) ->
    if error
      ImportingFile.documents.update file._id,
        $set:
          state: 'errored'
          status: "#{ error }"
      return

    ImportingFile.documents.update file._id,
      $set:
        state: 'imported'
        publicationId: publicationId
        status: "File imported"

uploadFile = (file, publicationId) ->
  meteorFile = new MeteorFile file,
    collection: ImportingFile.Meta.collection

  meteorFile.upload file, 'upload-publication',
    size: UPLOAD_CHUNK_SIZE,
    publicationId: publicationId
  ,
    (error) ->
      # When the user presses cancel we throw a special error. Here
      # we capture that error and handle it as a special case.
      if error is 'canceled'
        ImportingFile.documents.update file._id,
          $set:
            # We got back from the chunk upload, so we can mark it as
            # really canceled (that is, finished) and display to the
            # user that cancelling has been successful
            state: 'finished'
            status: "Import canceled"
        return

      if error
        ImportingFile.documents.update file._id,
          $set:
            state: 'errored'
            status: "#{ error }"
        return

      ImportingFile.documents.update file._id,
        $set:
          state: 'imported'
          publicationId: publicationId

# Process next element from import queue
Tracker.autorun ->
  # Autorun will not re-run when document changes status from 'preprocessed' to 'importing',
  # but after it changes to any other status, next file will be returned
  document = ImportingFile.documents.findOne
    canceled:
      $ne: true
    state:
      $in: ['importing', 'preprocessed']
  ,
    fields:
      id: 1
      name: 1
      sha256: 1
  return unless document

  updatedCount = ImportingFile.documents.update
    _id: document._id,
    canceled:
      $ne: true
    state:
      # But we want to continue only for files in 'preprocessed' state
      $in: ['preprocessed']
  ,
    $set:
      state: 'importing'
  return unless updatedCount

  Meteor.call 'create-publication', document.name, document.sha256, (error, result) ->
    if error
      ImportingFile.documents.update document._id,
        $set:
          state: 'errored'
          status: "#{ error }"
      return

    if result.already
      ImportingFile.documents.update document._id,
        $set:
          state: 'finished'
          status: "File already imported"
          publicationId: result.publicationId
      return

    if result.verify
      verifyFile importingFiles[document._id], result.publicationId, result.samples
    else
      uploadFile importingFiles[document._id], result.publicationId

computeChecksum = (file, callback) ->
  hash = new Crypto.SHA256
    onProgress: (progress) ->
      # We return false to prematurely stop computing checksum if file was canceled
      return false if ImportingFile.documents.findOne(file._id)?.canceled

      ImportingFile.documents.update file._id,
        $set:
          preprocessingProgress: progress * 100 # %

      # We return true to continue computing checksum
      return true

  hash.update file.content, (error) ->
    if error
      FlashMessage.error "Crypto error: #{ error }", null, true, error.stack
      ImportingFile.documents.update file._id,
        $set:
          state: 'errored'
          status: "#{ error }"
      return

    return callback null, null if ImportingFile.documents.findOne(file._id)?.canceled

    hash.finalize callback

testPDF = (file, callback) ->
  PDFJS.getDocument(data: file.content, password: '').then callback, (message, exception) ->
    ImportingFile.documents.update file._id,
      $set:
        state: 'errored'
        status: "Invalid PDF file"

# Process next element from preprocessing queue
Tracker.autorun ->
  # Autorun will not re-run when document changes status from 'new' to 'preprocessing',
  # but after it changes to any other status, next file will be returned
  document = ImportingFile.documents.findOne
    canceled:
      $ne: true
    state:
      $in: ['preprocessing', 'new']
  ,
    fields:
      _id: 1
  return unless document

  updatedCount = ImportingFile.documents.update
    _id: document._id
    canceled:
      $ne: true
    state:
      # But we want to continue only for files in 'new' state
      $in: ['new']
  ,
    $set:
      status: "Preprocessing"
      state: 'preprocessing'
  return unless updatedCount

  reader = new FileReader()
  reader.onload = ->
    importingFiles[document._id].content = reader.result
    testPDF importingFiles[document._id], ->
      computeChecksum importingFiles[document._id], (error, sha256) ->
        if error
          ImportingFile.documents.update document._id,
            $set:
              state: 'errored'
              status: "#{ error }"
          return

        if ImportingFile.documents.findOne(document._id)?.canceled
          ImportingFile.documents.update document._id,
            $set:
              state: 'finished'
              status: "Import canceled"
        else
          ImportingFile.documents.update document._id,
            $set:
              sha256: sha256
              status: "In import queue"
              state: 'preprocessed'

  reader.onerror = (error) ->
    FlashMessage.error "FileReader error: #{ error }", null, true, error.stack
    ImportingFile.documents.update document._id,
      $set:
        state: 'errored'
        status: "#{ error }"

  # TODO: Read file in chunks
  reader.readAsArrayBuffer importingFiles[document._id]

importFile = (file) ->
  id = Random.id()
  importingFiles[id] = file
  file._id = id

  # This will trigger preprocessing
  ImportingFile.documents.insert
    _id: id
    name: file.name
    status: "In preprocessing queue"
    readProgress: 0
    uploadProgress: 0
    preprocessingProgress: 0
    canceled: false
    state: 'new'

hideOverlay = ->
  allCount = ImportingFile.documents.find().count()
  erroredFinishedImportedCount = ImportingFile.documents.find(
    state:
      $in: ['errored', 'finished', 'imported']
  ).count()

  # We prevent hiding if user is uploading files
  if allCount is erroredFinishedImportedCount
    Session.set 'importOverlayActive', false
    ImportingFile.documents.remove {}

  Session.set 'signInOverlayActive', false

$(document).on 'dragstart', (event) ->
  # We want to prevent dragging of everything except jQuery UI controls
  return if $(event.target).is('.ui-draggable')

  event.preventDefault()

  return # Make sure CoffeeScript does not return anything

$(document).on 'dragenter', (event) ->
  event.preventDefault()

  # Don't allow importing while password reset is in progress
  return if  Accounts._loginButtonsSession.get 'resetPasswordToken'

  # For flickering issue: https://github.com/peerlibrary/peerlibrary/issues/203
  draggingOverDom = true
  Meteor.setTimeout ->
    draggingOverDom = false
  , 5 # ms

  if Meteor.personId()
    Session.set 'importOverlayActive', true
    event.originalEvent.dataTransfer.effectAllowed = 'copy'
    event.originalEvent.dataTransfer.dropEffect = 'copy'
  else
    Session.set 'signInOverlayActive', true
    event.originalEvent.dataTransfer.effectAllowed = 'none'
    event.originalEvent.dataTransfer.dropEffect = 'none'

  return # Make sure CoffeeScript does not return anything

importButtonEvent =
  'click .import, click .import-link': (event, template) ->
    event.preventDefault()

    if Meteor.personId()
      $('.import-file-input').click()
    else
      Session.set 'signInOverlayActive', true

    return # Make sure CoffeeScript does not return anything

Template.importButton.events importButtonEvent

Template.importButton.events
  'change input.import-file-input': (event, template) ->
    event.preventDefault()

    return if event.target.files?.length is 0

    Session.set 'importOverlayActive', true
    _.each event.target.files, importFile

    # Resets file so that it does not have any file selected. This assures
    # that change event is triggered even if the user selects the same file.
    # It is not really reasonable to do that, but it is still better that
    # we do something than simply nothing because no event is triggered.
    $(event.target).wrap('<form/>').closest('form').get(0).reset()
    $(event.target).unwrap()

    return # Make sure CoffeeScript does not return anything

Template.importLink.events importButtonEvent

Template.importingFilesItemCancel.events
  'click .cancel-button': (event, template) ->
    ImportingFile.documents.update @_id,
      $set:
        canceled: true

    return # Make sure CoffeeScript does not return anything

Template.importingFilesItem.helpers
  hideCancel: ->
    return unless @_id

    # We keep cancel shown even when canceled is set, until we get back
    # in the file upload method callback and set finished as well
    @state in ['finished', 'errored', 'imported']

  state: ->
    return unless @_id

    # Canceled could still be set, but state could be errored or imported if canceled was
    # set to late in the process, in which case we want not to display it as canceled.
    return @state if @state in ['errored', 'imported']
    # But otherwise if state is finished and canceled, we want to display it as canceled.
    # We also check for status text so that we make sure now some other status message is
    # displayed together with canceled state. We want progress bar background to be in canceled
    # color only when status is "Import canceled". But import could for example already finish
    # with "File already imported", but canceled could still be triggered, which would set the
    # flag, but not the status text.
    return 'canceled' if @canceled and @state is 'finished' and @status is "Import canceled"
    return @state

  publication: ->
    return unless @_id

    Publication.documents.findOne @publicationId

Template.signInOverlay.helpers
  signInOverlayActive: ->
    Session.get 'signInOverlayActive'

Template.signInOverlay.events
  'dragover': (event, template) ->
    event.preventDefault()
    event.originalEvent.dataTransfer.effectAllowed = 'none'
    event.originalEvent.dataTransfer.dropEffect = 'none'

    return # Make sure CoffeeScript does not return anything

  'dragleave': (event, template) ->
    event.preventDefault()

    unless draggingOverDom
      Session.set 'signInOverlayActive', false

    return # Make sure CoffeeScript does not return anything

  'drop': (event, template) ->
    event.stopPropagation()
    event.preventDefault()
    Session.set 'signInOverlayActive', false

    return # Make sure CoffeeScript does not return anything

  'click': (event, template) ->
    event.preventDefault()
    Session.set 'signInOverlayActive', false

    return # Make sure CoffeeScript does not return anything

Template.importOverlay.events
  'click .import': (event, template) ->
    $('.import-file-input').click()

  'dragover': (event, template) ->
    event.preventDefault()
    event.originalEvent.dataTransfer.effectAllowed = 'copy'
    event.originalEvent.dataTransfer.dropEffect = 'copy'

    return # Make sure CoffeeScript does not return anything

  'dragleave': (event, template) ->
    event.preventDefault()

    if ImportingFile.documents.find().count() == 0 and not draggingOverDom
      Session.set 'importOverlayActive', false

    return # Make sure CoffeeScript does not return anything

  'drop': (event, template) ->
    event.stopPropagation()
    event.preventDefault()

    unless Meteor.personId()
      Session.set 'importOverlayActive', false
      return

    _.each event.originalEvent.dataTransfer.files, importFile

    return # Make sure CoffeeScript does not return anything

  'click': (event, template) ->
    $target = $(event.target)

    # Allow click on cancel buttons
    return if $target.closest('.cancel-button').length

    # Allow click on import button
    return if $target.closest('.import').length

    # Don't close overlay if the user is interacting with one of the access controls (or other dropdowns)
    return if $target.closest('.access-control').length or $('.dropdown-anchor:visible').length

    hideOverlay()

    return # Make sure CoffeeScript does not return anything

Template.importOverlay.rendered = ->
  $(document).off('.importOverlay').on 'keyup.importOverlay', (event) =>
    hideOverlay() if event.keyCode is 27 # Escape key
    return # Make sure CoffeeScript does not return anything

Template.importOverlay.destroyed = ->
  $(document).off '.importOverlay'

Template.signInOverlay.rendered = Template.importOverlay.rendered

Template.signInOverlay.destroyed = Template.importOverlay.destroyed

Template.importOverlay.helpers
  importOverlayActive: ->
    Session.get 'importOverlayActive'

  importingFiles: ->
    ImportingFile.documents.find()

  importingFilesCount: ->
    ImportingFile.documents.find().count()

Tracker.autorun ->
  if Session.get('importOverlayActive') or Session.get('signInOverlayActive')
    # We prevent scrolling of page content while overlay is visible
    $('body').add('html').addClass 'overlay-active'
  else
    $('body').add('html').removeClass 'overlay-active'

Tracker.autorun ->
  importingFilesCount = ImportingFile.documents.find().count()

  return unless importingFilesCount

  finishedImportedFilesCount = ImportingFile.documents.find(state: $in: ['finished', 'imported']).count()

  # If there are any files still in progress or if there are any errors, do nothing
  return if importingFilesCount isnt finishedImportedFilesCount

  importedFilesCount = ImportingFile.documents.find(state: 'imported').count()

  # If no file was really imported (all canceled?)
  return unless importedFilesCount

  # Don't redirect if the user is interacting with one of the access controls (or other dropdowns)
  return if $('.dropdown-anchor:visible').length

  if importedFilesCount is 1
    FlashMessage.success "Imported the publication."
    Meteor.Router.toNew Meteor.Router.publicationPath ImportingFile.documents.findOne(state: 'imported').publicationId
  else
    FlashMessage.success "Imported #{ importedFilesCount } publications."
    Meteor.Router.toNew Meteor.Router.libraryPath()

  Session.set 'importOverlayActive', false

  ImportingFile.documents.remove {}
