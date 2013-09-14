PDFJS.pdfTextSegment = (textContent, i, geom) ->
  width = geom.canvasWidth * geom.hScale
  height = geom.fontSize * Math.abs geom.vScale
  left = geom.x
  top = geom.y
  text = textContent.bidiTexts[i].str
  direction = textContent.bidiTexts[i].dir

  if direction == 'ttb' # Vertical text
    # We rotate for 90 degrees
    # Example: http://blogs.adobe.com/CCJKType/files/2012/07/TaroUTR50SortedList112.pdf
    left -= height
    top -= width - height
    [height, width] = [width, height]

  # TODO: Return other values as well?
  left: left
  top: top
  width: width
  height: height
  direction: direction
  text: text
