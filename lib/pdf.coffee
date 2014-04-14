WHITESPACE_REGEX = /\s+/g
TRIM_WHITESPACE_REGEX = /^\s+|\s+$/gm

if Meteor.isClient
  ctx = document.createElement('canvas').getContext '2d'
else
  # TODO: Is OK if size here is hard-coded? Is it too big? Is this even used on the server?
  ctx = new PDFJS.canvas(1000, 1000).getContext '2d'

PDFJS.pdfTextSegment = (textContent, textContentIndex, geom) ->
  fontHeight = geom.fontSize * Math.abs(geom.vScale)
  fontAscent = if geom.ascent then geom.ascent * fontHeight else if geom.descent then (1 + geom.descent) * fontHeight else fontHeight
  canvasWidth = geom.canvasWidth * Math.abs(geom.hScale)

  segment =
    geom: geom
    text: textContent[textContentIndex].str
    direction: textContent[textContentIndex].dir
    angle: geom.angle
    textContentIndex: textContentIndex
    width: 0
    scale: 1

  segment.isWhitespace = !/\S/.test(segment.text)

  segment.style =
    fontSize: fontHeight
    fontFamily: geom.fontFamily
    left: geom.x + fontAscent * Math.sin(segment.angle)
    top: geom.y - fontAscent * Math.cos(segment.angle)

  unless segment.isWhitespace
    ctx.font = "#{ segment.style.fontSize }px #{ segment.style.fontFamily }"
    segment.width = ctx.measureText(segment.text).width

    assert segment.width >= 0, segment.width

    if segment.width
      angle = segment.angle * (180 / Math.PI)
      segment.scale = canvasWidth / segment.width
      segment.style.transform = "rotate(#{ angle }deg) scale(#{ segment.scale }, 1)"
      segment.style.transformOrigin = '0% 0%';

  segment.boundingBox =
    width: canvasWidth
    height: fontHeight
    left: segment.style.left
    top: segment.style.top

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
  geom: geom
  boundingBox: _.pick geom, 'left', 'top', 'width', 'height'
  style: _.pick geom, 'left', 'top', 'width', 'height'

PDFJS.pdfExtractText = (textContents...) ->
  texts = for textContent in textContents
    text = (t.str for t in textContent).join ' '

    # Remove multiple whitespace characters and trim them away
    text = text.replace(WHITESPACE_REGEX, ' ').replace(TRIM_WHITESPACE_REGEX, '')

    # TODO: Clean-up the text: remove hypenation

    text

  # TODO: What if there is hypenation between pages? We should not just add space in-between then?
  texts.join ' '
