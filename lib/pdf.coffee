PDFJS.pdfTextSegment = (pageHeigh, textContent, i, geom) ->
  width = geom.canvasWidth * geom.hScale
  height = geom.fontSize * Math.abs geom.vScale
  x = geom.x
  y = pageHeigh - geom.y
  text = textContent.bidiTexts[i].str
  direction = textContent.bidiTexts[i].dir

  if direction == 'ttb' # Vertical text
    # We rotate for 90 degrees
    # Example: http://blogs.adobe.com/CCJKType/files/2012/07/TaroUTR50SortedList112.pdf
    x -= height
    y -= width - height
    [height, width] = [width, height]

  x: x
  y: y
  width: width
  height: height
  direction: direction
  text: text
