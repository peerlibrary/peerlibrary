DEBUG = false
NOT_WHITESPACE = /\S/

PDFJS.LogManager.addLogger
  warn: (args...) ->
    #console.log "pdf.js:", args... if args

bindEnvironemnt = (f) ->
  Meteor.bindEnvironment f, (e) -> throw e

PDF =
  process: (pdfFile, initCallback, textCallback, pageImageCallback, progressCallback) ->
    document = PDFJS.getDocumentSync
      data: pdfFile
      password: ''

    initCallback document.numPages

    #metadata = document.getMetadataSync pageNumber
    #console.log "Metadata", metadata

    for pageNumber in [1..document.numPages]
      page = document.getPageSync pageNumber

      assert.equal pageNumber, page.pageNumber

      progressCallback (page.pageNumber - 1) / document.numPages

      #annotations = page.getAnnotationsSync()
      #console.log "Annotations", annotations

      textContent = page.getTextContentSync()

      viewport = page.getViewport 1.0
      canvasElement = new PDFJS.canvas viewport.width, viewport.height
      canvasContext = canvasElement.getContext '2d'
      appendCounter = 0

      page.renderSync
        canvasContext: canvasContext
        viewport: viewport
        textLayer:
          beginLayout: bindEnvironemnt ->
            #console.log "beginLayout"

          endLayout: bindEnvironemnt ->
            #console.log "endLayout"

            if DEBUG
              # Save the canvas (with rectangles around text segments)
              png = fs.createWriteStream 'debug' + page.pageNumber + '.png'
              canvasElement.pngStream().pipe png

            pageImageCallback page.pageNumber, canvasElement

          appendText: bindEnvironemnt (geom) ->
            width = geom.canvasWidth * geom.hScale
            height = geom.fontSize * Math.abs geom.vScale
            x = geom.x
            y = viewport.height - geom.y
            text = textContent.bidiTexts[appendCounter].str
            direction = textContent.bidiTexts[appendCounter].dir

            if direction == 'ttb' # Vertical text
              # We rotate for 90 degrees
              # Example: http://blogs.adobe.com/CCJKType/files/2012/07/TaroUTR50SortedList112.pdf
              x -= height
              y -= width - height
              [height, width] = [width, height]

            appendCounter++

            if !NOT_WHITESPACE.test text
              return

            if DEBUG
              # Draw a rectangle around the text segment
              canvasContext.strokeRect x, y, width, height

            textCallback page.pageNumber, x, y, width, height, direction, text

    progressCallback 1.0

    return # So that we do not return any results

@PDF = PDF
