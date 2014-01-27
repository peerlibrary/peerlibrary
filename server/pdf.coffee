DEBUG = false

bindEnvironemnt = (f) ->
  Meteor.bindEnvironment f, (e) -> throw e

PDF =
  process: (pdfFile, initCallback, textCallback, pageImageCallback, progressCallback) ->
    document = PDFJS.getDocumentSync
      data: pdfFile
      password: ''

    initCallback document.numPages

    #metadata = document.getMetadataSync pageNumber
    #Log.debug "Metadata #{ util.inspect metadata, false, null }"

    for pageNumber in [1..document.numPages]
      page = document.getPageSync pageNumber

      assert.equal pageNumber, page.pageNumber

      progressCallback (page.pageNumber - 1) / document.numPages

      #annotations = page.getAnnotationsSync()
      #Log.debug "Annotations #{ util.inspect annotations, false, null }"

      textContent = page.getTextContentSync()

      viewport = page.getViewport 1.0
      canvasElement = new PDFJS.canvas viewport.width, viewport.height
      canvasContext = canvasElement.getContext '2d'
      appendCounter = 0

      defaultContext = _.omit canvasContext, 'canvas', _.functions canvasContext

      page.renderSync
        canvasContext: canvasContext
        viewport: viewport
        textLayer:
          beginLayout: bindEnvironemnt ->
            #Log.debug "beginLayout"

          endLayout: bindEnvironemnt ->
            #Log.debug "endLayout"

            if DEBUG
              # Save the canvas (with rectangles around text segments)
              png = fs.createWriteStream 'debug' + page.pageNumber + '.png'
              canvasElement.pngStream().pipe png

            pageImageCallback page.pageNumber, canvasElement

          appendText: bindEnvironemnt (geom) ->
            # TODO: Verify it still draws correctly on the server
            segment = PDFJS.pdfTextSegment textContent, appendCounter, geom

            appendCounter++

            if segment.hasWidth and DEBUG
              canvasContext.save()

              # We reset context
              canvasContext.setTransform(1, 0, 0, 1, 0, 0);
              canvasContext.resetClip?(); # TODO: In standard, but not yet available in node-canvas: https://github.com/LearnBoost/node-canvas/issues/358
              _.extend canvasContext, defaultContext

              # Draw a rectangle around the text segment
              canvasContext.strokeStyle = '#CC0000'
              canvasContext.strokeRect segment.boundingBox.left, segment.boundingBox.top, segment.boundingBox.width, segment.boundingBox.height

              canvasContext.restore()

            textCallback page.pageNumber, segment

    progressCallback 1.0

    return # So that we do not return any results

@PDF = PDF
