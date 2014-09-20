WHITESPACE_REGEX = /\s+/g
NON_WHITESPACE_REGEX = /\S/

if Meteor.isClient
  ctx = document.createElement('canvas').getContext '2d'
else
  # TODO: Is OK if size here is hard-coded? Is it too big? Is this even used on the server?
  ctx = new PDFJS.canvas(1000, 1000).getContext '2d'

lastFont = null

isAllWhitespace = (str) ->
  not NON_WHITESPACE_REGEX.test str

# Based on PDF.js TextLayerBuilder_appendText and TextLayerBuilder_renderLayer
# Returns a segment:
#   geom: original PDF.js geom object
#   text: text content of the text segment
#   direction: direction of the text segment
#   angle: angle in radians (same value used in CSS transformation)
#   scaleX: X-axis scaling (same value used in CSS transformation)
#   isWhitespace: does it have only whitespace in text
#   style: CSS style to apply to the segment when displaying it
#   boundingBox:
#     left
#     top
#     width
#     height
#   hasArea: true if segment has any area
PDFJS.pdfTextSegment = (viewport, geom, styles) ->
  segment =
    geom: geom
    text: geom.str
    direction: geom.dir
    angle: 0
    scaleX: 1

  segment.isWhitespace = isAllWhitespace segment.text

  return segment if segment.isWhitespace

  style = styles[geom.fontName]

  tx = PDFJS.Util.transform viewport.transform, geom.transform

  angle = Math.atan2(tx[1], tx[0])
  angle += Math.PI / 2 if style.vertical

  fontHeight = Math.sqrt((tx[2] * tx[2]) + (tx[3] * tx[3]))

  fontAscent = fontHeight
  if style.ascent
    fontAscent = style.ascent * fontAscent
  else if style.descent
    fontAscent = (1 + style.descent) * fontAscent

  if angle is 0
    left = tx[4]
    top = tx[5] - fontAscent
  else
    left = tx[4] + (fontAscent * Math.sin(angle))
    top = tx[5] - (fontAscent * Math.cos(angle))

  segment.style =
    left: left + 'px'
    top: top + 'px'
    fontSize: fontHeight + 'px'
    fontFamily: style.fontFamily

  segment.angle = angle

  if style.vertical
    canvasWidth = geom.height * viewport.scale
    canvasHeight = geom.width * viewport.scale
  else
    canvasWidth = geom.width * viewport.scale
    canvasHeight = geom.height * viewport.scale

  assert canvasWidth >= 0, canvasWidth
  assert canvasHeight >= 0, canvasHeight

  # Approximately equal
  assert Math.abs(canvasHeight - fontHeight) < 0.0001, "canvasHeight: #{ canvasHeight }, fontHeight: #{ fontHeight }"

  # Only build font string and set to context if different from last.
  newFont = "#{ segment.style.fontSize } #{ segment.style.fontFamily }"
  if newFont isnt lastFont
    ctx.font = newFont
    lastFont = newFont

  width = ctx.measureText(segment.text).width

  assert width >= 0, width

  if width
    transforms = []

    # We don't bother scaling single-char text divs, because it has very
    # little effect on text highlighting. This makes scrolling on docs with
    # lots of such divs a lot faster.
    if segment.text.length > 1
      segment.scaleX = canvasWidth / width
      transforms.push "scaleX(#{ segment.scaleX })"
    if segment.angle isnt 0.0
      angleDegrees = segment.angle * (180 / Math.PI)
      transforms.push "rotate(#{ angleDegrees }deg)"

    if transforms.length
      segment.style.transform = transforms.join ' '
      segment.style.transformOrigin = '0 0'

  segment.boundingBox =
    left: left
    top: top
    width: canvasWidth
    height: canvasHeight
  segment.hasArea = canvasWidth * canvasHeight > 0.0

  # When the angle is not 0, we rotate and compute the bounding box of the rotated segment
  if segment.angle isnt 0.0
    x = [
      segment.boundingBox.left
      segment.boundingBox.left + segment.boundingBox.width * Math.cos(segment.angle)
      segment.boundingBox.left - segment.boundingBox.height * Math.sin(segment.angle)
      segment.boundingBox.left + segment.boundingBox.width * Math.cos(segment.angle) - segment.boundingBox.height * Math.sin(segment.angle)
    ]
    y = [
      segment.boundingBox.top
      segment.boundingBox.top + segment.boundingBox.width * Math.sin(segment.angle)
      segment.boundingBox.top + segment.boundingBox.height * Math.cos(segment.angle)
      segment.boundingBox.top + segment.boundingBox.width * Math.sin(segment.angle) + segment.boundingBox.height * Math.cos(segment.angle)
    ]

    segment.boundingBox.left = _.min(x)
    segment.boundingBox.top = _.min(y)

    segment.boundingBox.width = _.max(x) - segment.boundingBox.left
    segment.boundingBox.height = _.max(y) - segment.boundingBox.top

  segment

PDFJS.pdfImageSegment = (geom) ->
  pickedGeom = _.pick geom, 'left', 'top', 'width', 'height'
  geom: geom
  boundingBox: pickedGeom
  style:
    left: pickedGeom.left + 'px'
    top: pickedGeom.top + 'px'
    width: pickedGeom.width + 'px'
    height: pickedGeom.height + 'px'

# This has to be in sync with how browser text selection is converted to a string (it adds
# a space between divs) and how it is then normalized in DomTextMapper.readSelectionText,
# DomTextMatcher.readSelectionText, Annotator.normalizeString (they trim and replace white space)
PDFJS.pdfExtractText = (textContents...) ->
  texts = for textContent in textContents
    text = (geom.str for geom in textContent.items).join ' '

    # Trim and remove multiple whitespace characters
    text = text.trim().replace(WHITESPACE_REGEX, ' ')

    # TODO: Clean-up the text: remove hyphenation (be careful, DomTextMapper.readSelectionText should do the same then)

    text

  # TODO: What if there is hyphenation between pages? We should not just add space in-between then?
  texts.join ' '
