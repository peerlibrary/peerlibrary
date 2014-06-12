# Local (client-only) document of importing files
class ImportingFile extends Document
  # name: user's file name
  # readProgress: progress of reading from file, in %
  # uploadProgress: progress of uploading file, in %
  # status: current status or error message
  # finished: true when importing has finished
  # errored: true when there was an error
  # canceled: true when user cancels import
  # imported: true if file was successfully imported
  # publicationId: publication ID for the imported file
  # sha256: SHA256 hash for the file

  @Meta
    name: 'ImportingFile'
    collection: null

UPLOAD_CHUNK_SIZE = 128 * 1024 # bytes
DRAGGING_OVER_DOM = false
fileBuffer = []
# current element of checksum and upload queue
currentDocument =
  checksum: null
  upload: null

# observes files that are processed and removes them from buffer
processedFiles = ImportingFile.documents.find
  $or: [
    finished: true
  ,
    errored: true
  ]
processedFiles.observe
  added: (document) ->
    delete fileBuffer[document._id]

# verify or upload next file from queue
Deps.autorun ->
  document = ImportingFile.documents.findOne
    finished: false
    errored: false
    sha256:
      $exists: true

  # document will be null the first time it runs
  # also, autorun will get called when document status changes
  # if document id is unchanged it can return
  return if not document or currentDocument.upload and currentDocument.upload._id == document._id
  currentDocument.upload = document

  Meteor.call 'create-publication', document.name, document.sha256, (error, result) ->
    if error
      ImportingFile.documents.update document._id,
        $set:
          errored: true
          status: error.toString()
      return

    if result.already
      ImportingFile.documents.update document._id,
        $set:
          finished: true
          status: "File already imported"
          publicationId: result.publicationId
      return

    if result.verify
      verifyFile fileBuffer[document._id].file, fileBuffer[document._id].fileContent, result.publicationId, result.samples
    else
      uploadFile fileBuffer[document._id].file, result.publicationId

# calculate checksum for next file in queue
Deps.autorun ->
  document = ImportingFile.documents.findOne
    preprocessed: true
    sha256:
      $exists: false

  # document will be null the first time it runs
  # also, autorun will get called when document status changes
  # if document id is unchanged it can return
  return if not document or currentDocument.checksum and currentDocument.checksum._id == document._id
  currentDocument.checksum = document

  ImportingFile.documents.update document._id,
    $set:
      status: "Computing checksum"

  hash = new Crypto.SHA256
    onProgress: (progress) ->
      #TODO: update progressbar
  hash.update fileBuffer[document._id].fileContent, (error, result) ->
    #TODO: handle errors
    if error
      console.log "Import error: " + error.message
  hash.finalize (error, result) ->
    #TODO: handle errors
    if error
      console.log "Import error: " + error.message

    ImportingFile.documents.update document._id,
      $set:
        sha256: result
        status: "Checksum computed"

verifyFile = (file, fileContent, publicationId, samples) ->
  ImportingFile.documents.update file._id,
    $set:
      status: "Verifying file"

  samplesData = _.map samples, (sample) ->
    new Uint8Array fileContent.slice sample.offset, sample.offset + sample.size
  Meteor.call 'verify-publication', publicationId, samplesData, (error) ->
    if error
      ImportingFile.document.update file._id,
        $set:
          errored: true
          status: error.toString()
      return

    ImportingFile.document.update file._id,
      $set:
        finished: true
        imported: true
        publicationId: publicationId
        status: "File imported"

uploadFile = (file, publicationId) ->
  ImportingFile.documents.update file._id,
    $set:
      status: "Uploading file"
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
            finished: true
            status: "Import canceled"
        return

      if error
        ImportingFile.documents.update file._id,
          $set:
            errored: true
            status: error.toString()
        return

      ImportingFile.documents.update file._id,
        $set:
          finished: true
          imported: true
          publicationId: publicationId

testPDF = (file, fileContent, callback) ->
  PDFJS.getDocument(data: fileContent, password: '').then callback, (message, exception) ->
    ImportingFile.documents.update file._id,
      $set:
        errored: true
        status: "Invalid PDF file"

importFile = (file) ->
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

  ImportingFile.documents.insert
    name: file.name
    status: "Preprocessing file"
    readProgress: 0
    uploadProgress: 0
    finished: false
    errored: false
    canceled: false
    imported: false
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

Template.importingFilesItem.events =
  'click .cancel-button': (e) ->
    e.preventDefault()
    # We stop event propagation to prevent the
    # cancel from bubbling up to hide the overlay
    e.stopPropagation()

    ImportingFile.documents.update @_id,
      $set:
        canceled: true

    return # Make sure CoffeeScript does not return anything

Template.importingFilesItem.hideCancel = ->
  # We keep cancel shown even when canceled is set, until we get back
  # in the file upload method callback and set finished as well
  @finished or @errored

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
    # We are stopping propagation in click on cancel
    # button but it still propagates so we cancel here
    # TODO: Check if this is still necessary in the new version of Meteor
    return if e.isPropagationStopped()

    hideOverlay()

    return # Make sure CoffeeScript does not return anything

Template.importOverlay.rendered = ->
  $(document).off('.importOverlay').on 'keyup.importOverlay', (e) =>
    hideOverlay() if e.keyCode is 27 # Escape key
    return # Make sure CoffeeScript does not return anything

Template.importOverlay.destroyed = ->
  $(document).off '.importOverlay'

Template.signInOverlay.rendered = Template.importOverlay.rendered

Template.signInOverlay.destroyed = Template.importOverlay.destroyed

Template.importOverlay.importOverlayActive = ->
  Session.get 'importOverlayActive'

Template.importOverlay.importingFiles = ->
  ImportingFile.documents.find()

Deps.autorun ->
  if Session.get('importOverlayActive') or Session.get('signInOverlayActive')
    # We prevent scrolling of page content while overlay is visible
    $('body').add('html').addClass 'overlay-active'
  else
    $('body').add('html').removeClass 'overlay-active'

Deps.autorun ->
  importingFilesCount = ImportingFile.documents.find().count()

  return unless importingFilesCount

  finishedFilesCount = ImportingFile.documents.find(finished: true).count()

  # If there are any files still in progress or if there are any errors, do nothing
  return if importingFilesCount isnt finishedFilesCount

  importedFilesCount = ImportingFile.documents.find(imported: true).count()

  # If no file was really imported (all canceled?)
  return unless importedFilesCount

  if importedFilesCount is 1
    Notify.success "Imported the publication."
    Meteor.Router.toNew Meteor.Router.publicationPath ImportingFile.documents.findOne(imported: true).publicationId
  else
    Notify.success "Imported #{ importedFilesCount } publications."
    Meteor.Router.toNew Meteor.Router.libraryPath()

  Session.set 'importOverlayActive', false

  ImportingFile.documents.remove {}
