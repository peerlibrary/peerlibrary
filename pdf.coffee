assert = require 'assert'
btoa = require 'btoa'
canvas = require 'canvas'
fs = require 'fs'
jsdom = require 'jsdom'
vm = require 'vm'
xmldom = require 'xmldom'

_ = require 'underscore'

DEBUG = false

# Copy from pdf.js/make.js
SRC_FILES = [
  'core.js',
  'util.js',
  'api.js',
  'canvas.js',
  'obj.js',
  'function.js',
  'charsets.js',
  'cidmaps.js',
  'colorspace.js',
  'crypto.js',
  'evaluator.js',
  'fonts.js',
  'glyphlist.js',
  'image.js',
  'metrics.js',
  'parser.js',
  'pattern.js',
  'stream.js',
  'worker.js',
  'jpx.js',
  'jbig2.js',
  'bidi.js',
  'metadata.js',
]

NOT_WHITESPACE = /\S/

PDFJS = {}

window = jsdom.jsdom().createWindow()
window.btoa = btoa
window.DOMParser = xmldom.DOMParser
window.PDFJS = PDFJS

if DEBUG
  window.console = console

# So that isSyncFontLoadingSupported returns true
window.navigator.userAgent = 'Mozilla/5.0 rv:14 Gecko'

# TODO: To be secure, we do not have to pass everything in the context, like "require" and "process" and "global" itself?
context = vm.createContext _.extend {}, global, window, {window: window}

for file in SRC_FILES
  path = require.resolve 'pdf.js/src/' + file
  content = fs.readFileSync path, 'utf8'
  vm.runInContext content, context, path

context.createScratchCanvas = (width, height) ->
  new canvas(width, height)

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
          beginLayout: () ->
            #console.log "beginLayout"
          endLayout: () ->
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
            console.log(x, y, width, height, text)

        viewport = page.getViewport 1.0
        canvasElement = new canvas(viewport.width, viewport.height)
        canvasContext = canvasElement.getContext '2d'

        renderContext =
          canvasContext: canvasContext
          viewport: viewport
          textLayer: textLayer

        page.render(renderContext).then () ->
          return # Do nothing
        , (error) ->
          console.error "PDF Error", error

    pdf.getMetadata(pageNumber).then (metadata) ->
      #console.log "Metadata", metadata

  return # So that we do not return the results of the for-loop

processError = (message, exception) ->
  console.error "PDF Error", message, exception

PDFJS.getDocument({data: pdfFile, password: ''}).then processPDF, processError
