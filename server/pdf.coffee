do -> # To not pollute the namespace
  require = __meteor_bootstrap__.require

  canvas = require 'canvas'
  fs = require 'fs'

  DEBUG = false
  NOT_WHITESPACE = /\S/

  # TODO: Temporary hard-coded for testing, create API for all this
  pdfFile = new Uint8Array fs.readFileSync '/Users/mitar/Downloads/adida.pdf'

  processPDF = (pdf) ->
    for pageNumber in [1..pdf.numPages]
      pdf.getPage(pageNumber).then (page) ->
        # pageNumber is not necessary current page number once promise is resolved, use page.pageNumber instead

        page.getAnnotations().then (annotations) ->
          #console.log "Annotations", annotations

        page.getTextContent().then (textContent) ->
          appendCounter = 0
          textLayer =
            beginLayout: ->
              #console.log "beginLayout"
            endLayout: ->
              #console.log "endLayout"
            appendText: (geom) ->
              width = geom.canvasWidth * geom.hScale
              height = geom.fontSize * Math.abs(geom.vScale)
              x = geom.x
              y = viewport.height - geom.y
              text = textContent.bidiTexts[appendCounter].str
              appendCounter++

              if !NOT_WHITESPACE.test(text)
                return

              if DEBUG
                canvasContext.strokeRect(x, y, width, height)
                png = fs.createWriteStream('debug' + page.pageNumber + '.png')
                canvasElement.pngStream().pipe(png)

              # TODO: Store into the database and find paragrahps
              # TODO: We should just allow user to provide a callback
              console.log(x, y, width, height, text)

          viewport = page.getViewport 1.0
          canvasElement = new canvas(viewport.width, viewport.height)
          canvasContext = canvasElement.getContext '2d'

          renderContext =
            canvasContext: canvasContext
            viewport: viewport
            textLayer: textLayer

          page.render(renderContext).then ->
            return # Do nothing
          , (error) ->
            console.error "PDF Error", error

      pdf.getMetadata(pageNumber).then (metadata) ->
        #console.log "Metadata", metadata

    return # So that we do not return the results of the for-loop

  processError = (message, exception) ->
    console.error "PDF Error", message, exception

  PDFJS.getDocument({data: pdfFile, password: ''}).then processPDF, processError
