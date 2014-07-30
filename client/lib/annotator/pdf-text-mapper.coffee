class PDFTextMapper extends PageTextMapperCore
  # Are we working with a PDF document?
  @applicable: =>
    # We unconditially report as applicable, but we conditionally load the plugin itself
    true

  requiresSmartStringPadding: true

  # Get the number of pages
  getPageCount: =>
    @_highlighter.getNumPages()

  # Where are we in the document?
  getPageIndex: =>
    # Ignoring, because used only by Hypothes.is heatmap
    throw new Error "Not implemented"

  # Jump to a given page
  setPageIndex: (index) =>
    # Ignoring, because used only by Hypothes.is heatmap
    throw new Error "Not implemented"

  # Determine whether a given page has been rendered
  _isPageRendered: (index) =>
    @_highlighter.isPageRendered index + 1

  # Get the root DOM node of a given page
  getRootNodeForPage: (index) ->
    @_highlighter.getTextLayer index + 1

  constructor: (@_highlighter) ->
    @pageInfo = []

  destroyed: =>
    @pageInfo = []

    # TODO: Remove events

  pageRendered: (pageNumber) =>
    assert @pageInfo.length

    @_onPageRendered pageNumber - 1

  pageRemoved: (pageNumber) =>
    assert @pageInfo.length

    # Forget info about the new DOM subtree
    @_unmapPage @pageInfo[pageNumber - 1]

  setEvents: =>
    # Do something about cross-page selections
    @_annotator.wrapper.on 'domChange.annotator', (event) =>
      data = event.data or event.originalEvent.data

      return unless event.target is event.currentTarget

      #console.log "Detected cross-page change event."

      # This event escaped the pages
      # Must be a cross-page selection
      return unless data.start? and data.end?

      startPage = @getPageForNode data.start
      endPage = @getPageForNode data.end
      # Update start and end page, where start and end of selection
      # possibly split text content of a text layer segmetn into two
      @_updateMap @pageInfo[startPage.index]
      @_updateMap @pageInfo[endPage.index] unless startPage.index is endPage.index

      return # Make sure CoffeeScript does not return anything

    # Ignoring, because used only by Hypothes.is heatmap
    #$(document).on 'scroll.annotator', (event) => @_onScroll()

  # Extract the text from the PDF
  scan: =>
    @pageInfo = for pageNumber in [1..@getPageCount()]
      content: @_highlighter.extractText pageNumber

    @_finishScan()

    # We are not returning any promise
    null

  # This is called when scanning is finished
  _finishScan: =>
    # Do some besic calculations with the content
    @_onHavePageContents()

    # Do whatever we need to do after scanning
    @_onAfterScan()

  # Look up the page for a given DOM node
  getPageForNode: (node) =>
    index = $(node).closest('.text-layer-segment').data('pageNumber') - 1
    @pageInfo[index]

# Annotator plugin for annotating documents handled by PDF.js
class Annotator.Plugin.PeerLibraryPDF extends Annotator.Plugin
  pluginInit: =>
    # We need dom-text-mapper
    unless @annotator.plugins.DomTextMapper
      throw new Error "The PeerLibrary PDF Annotator plugin requires the DomTextMapper plugin."

    @annotator.documentAccessStrategies.unshift
      # Strategy to handle PeerLibrary PDF documents
      name: 'PeerLibrary PDF'
      mapper: PDFTextMapper
      init: =>
        @annotator.domMapper._annotator = @annotator
        @annotator.domMapper._highlighter = @annotator._highlighter
        @annotator.domMapper.setEvents()
