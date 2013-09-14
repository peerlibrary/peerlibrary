PDFJS.pdfTextSegment = (textContent, i, geom) ->
  fontHeight = geom.fontSize * Math.abs geom.vScale
  width = geom.canvasWidth * Math.abs geom.hScale
  height = fontHeight
  left = geom.x + fontHeight * Math.sin geom.angle
  top = geom.y - fontHeight * Math.cos geom.angle
  text = textContent.bidiTexts[i].str
  direction = textContent.bidiTexts[i].dir

  # TODO: Should rotate segment based on the angle

  # TODO: Return other values as well?
  left: left
  top: top
  width: width
  height: height
  direction: direction
  text: text
