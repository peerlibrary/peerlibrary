fs = Npm.require 'fs'

DEBUG = false

PDF =
  process: (pdfFile, initCallback, textContentCallback, pageImageCallback, progressCallback) ->
    document = PDFJS.getDocumentSync
      data: pdfFile
      password: ''

    initCallback document.numPages

    #metadata = document.getMetadataSync pageNumber
    #Log.console "Metadata #{ util.inspect metadata, false, null }"

    for pageNumber in [1..document.numPages]
      page = document.getPageSync pageNumber

      assert.equal pageNumber, page.pageNumber

      progressCallback (page.pageNumber - 1) / document.numPages

      #annotations = page.getAnnotationsSync()
      #Log.console "Annotations #{ util.inspect annotations, false, null }"

      textContent = page.getTextContentSync()

      textContentCallback page.pageNumber, textContent

      viewport = page.getViewport 1.0
      canvasElement = new PDFJS.canvas viewport.width, viewport.height
      canvasContext = canvasElement.getContext '2d'

      defaultContext = _.omit canvasContext, 'canvas', _.functions canvasContext

      page.renderSync
        canvasContext: canvasContext
        viewport: viewport

      pageImageCallback page.pageNumber, canvasElement

      continue unless DEBUG

      # If debugging is enabled, we save every page canvas to a PNG file with rectangles around text segments.
      # They are stored in our storage under "debug" top-level directory. There is no information about publications
      # in the filename, so processing multiple publications will get a combination of all pages of all publications
      # together, with later publications overriding previous publications' pages.

      for geom in textContent.items
        segment = PDFJS.pdfTextSegment viewport, geom, textContent.styles

        continue if segment.isWhitespace or not segment.hasArea

        canvasContext.save()

        # We reset context
        canvasContext.setTransform 1, 0, 0, 1, 0, 0
        canvasContext.resetClip?() # TODO: In standard, but not yet available in node-canvas: https://github.com/LearnBoost/node-canvas/issues/358
        _.extend canvasContext, defaultContext

        # Draw a rectangle around the text segment
        canvasContext.strokeStyle = '#CC0000' # red
        canvasContext.strokeRect segment.boundingBox.left, segment.boundingBox.top, segment.boundingBox.width, segment.boundingBox.height

        canvasContext.restore()

      # Zero-padding of page number. We have to first pipe pngStream through through because pngStream is lacking
      # all necessary methods (like pause). See https://github.com/Automattic/node-canvas/issues/232#issuecomment-56253111
      Storage.saveStream "debug/#{ ('0000' + page.pageNumber).substr(-4, 4) }.png", canvasElement.pngStream().pipe(PDFJS.through())

    progressCallback 1.0

    return # So that we do not return any results

@PDF = PDF
