PDFJS.pdfTextSegment = (textContent, i, geom) ->
  fontHeight = geom.fontSize * Math.abs geom.vScale
  width = geom.canvasWidth * Math.abs geom.hScale
  height = fontHeight
  left = geom.x + fontHeight * Math.sin geom.angle
  top = geom.y - fontHeight * Math.cos geom.angle
  text = textContent.bidiTexts[i].str
  direction = textContent.bidiTexts[i].dir

  # When the angle is not 0, we rotate and compute the bounding box of the rotated segment
  if geom.angle isnt 0.0
    x = [left, left + width * Math.cos(geom.angle), left - height * Math.sin(geom.angle), left + width * Math.cos(geom.angle) - height * Math.sin(geom.angle)]
    y = [top, top + width * Math.sin(geom.angle), top + height * Math.cos(geom.angle), top + width * Math.sin(geom.angle) + height * Math.cos(geom.angle)]

    left = _.min(x)
    top = _.min(y)

    width = _.max(x) - left
    height = _.max(y) - top

  # TODO: Return other values as well?
  left: left
  top: top
  width: width
  height: height
  direction: direction
  text: text

PDFJS.pdfImageSegment = (geom) ->
  _.pick geom, 'left', 'top', 'width', 'height'
