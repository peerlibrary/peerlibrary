PDFJS.pdfTextSegment = (textContent, i, geom) ->
  fontHeight = geom.fontSize * Math.abs geom.vScale
  width = geom.canvasWidth * Math.abs geom.hScale
  height = fontHeight
  left = geom.x + fontHeight * Math.sin geom.angle
  top = geom.y - fontHeight * Math.cos geom.angle
  text = textContent.bidiTexts[i].str
  direction = textContent.bidiTexts[i].dir

  #if direction == 'ttb' # Vertical text
    # We rotate for 90 degrees
    # Example: http://blogs.adobe.com/CCJKType/files/2012/07/TaroUTR50SortedList112.pdf
  #  left -= height
  #  top -= width - height
  #  [height, width] = [width, height]

  # TODO: Return other values as well?
  left: left
  top: top
  width: width
  height: height
  direction: direction
  text: text
