Template.indexStatistics.publications = ->
  searchResult = SearchResults.findOne
    query: null

  searchResult?.countPublications or 0

Template.indexStatistics.persons = ->
  searchResult = SearchResults.findOne
    query: null

  searchResult?.countPersons or 0

Template.index.searchActive = ->
  Session.get 'searchActive'

# landing background
stage = undefined
renderer = undefined
ratio = undefined

triangles = []
vectors   = []
  
Vector = (x,y) ->
  @originX = @x = x or 0
  @originY = @y = y or 0
  @deltaX = 0
  @deltaY = 0

Vector::update = (time) ->
  distance = Math.sin(Math.min(Math.abs(@originY + 0.5 * @originX + 150 - (time / 2) / 5 % (Math.max(window.innerWidth, window.innerHeight) + 300)) / Math.sqrt(1.25), 200) / 200 * Math.PI / 2) * 60
  if not @duration or time > @start + @duration
    @start = time
    @duration = Math.random() * 2000 + 5000
    @deltaX = Math.random() * 8 + 5
    @deltaY = Math.random() * 20 + 5
  delta = (time - @start) / @duration
  sin = Math.sin(delta * Math.PI * 2)
  @x = @originX + sin * @deltaX + distance
  @y = @originY + sin * @deltaY + distance

Vector::toString = ->
  "#<Vector x: " + this.x + ", y: " + this.y + ">"

Triangle = (v0, v1, v2) ->
  @v0 = v0 or new Vector()
  @v1 = v1 or new Vector()
  @v2 = v2 or new Vector()
  @graphics = new PIXI.Graphics()
  stage.addChild @graphics

Triangle::draw = ->
  graphics = @graphics
  graphics.clear()
  graphics.beginFill @color(), 0.2
  graphics.lineStyle 1 * ratio, 0xFFFFFF, 0.4
  graphics.moveTo @v0.x * ratio, @v0.y * ratio
  graphics.lineTo @v1.x * ratio, @v1.y * ratio
  graphics.lineTo @v2.x * ratio, @v2.y * ratio
  graphics.endFill()

Triangle::area = ->
  Math.abs (@v0.x * @v1.y - @v1.x * @v0.y + @v1.x * @v2.y - @v2.x * @v1.y + @v2.x * @v0.y - @v0.x * @v2.y) / 2

Triangle::color = ->
  h = (@area() / 100) / 360
  s = (@area() / 100) / 100
  l = (25 + @area() / 100) / 100
  #a = 0.2
  hslToRgb h, s, l
  
Triangle::toString = ->
  "#<Triangle v0: "  + @v0.toString() + ", v1: " + @v1.toString() + ", v2: " + @v2.toString() + ">"

hslToRgb = (h, s, l) ->
  r = undefined
  g = undefined
  b = undefined
  if s is 0
    r = g = b = l
  else
    hue2rgb = (p, q , t) ->
      t += 1 if t < 0
      t -= 1 if t > 1
      return p + (q - p) * 6 * t if t < 1 / 6
      return q if t < 1 / 2
      return p + (q - p) * (2 / 3 -t) * 6 if t < 2 / 3
      p

    q = (if l < 0.5 then l * (l + s) else l + s - l * s)
    p = 2 * l - q
    r = hue2rgb(p, q, h + 1 / 3)
    g = hue2rgb(p, q, h)
    b = hue2rgb(p, q, h - 1 / 3)
    
  ((r * 255) << 16) + ((g * 255) << 8) + (b * 255)

draw = (time) ->
  i = 0
  len = vectors.length
  while i < len
    vectors[i].update time
    i++

  i = 0
  len = triangles.length
  while i < len
    triangles[i].draw()
    i++

  renderer.render stage
  requestAnimationFrame draw

generateTriangles = ->
  getVector = (x, y) ->
    key = x + "," + y
    value = hash[key]
    if value
      value
    else
      vector = new Vector(x, y)
      vectors.push vector
      hash[key] = vector
      vector

  originX = -200
  originY = -200
  width   = window.innerWidth + 280
  height  = window.innerHeight + 280
  deltaX  = 140
  deltaY  = 52
  columns = Math.ceil(width / deltaX)
  rows    = Math.ceil(height / deltaY)
  hash    = {}

  stage = new PIXI.Stage(0xFFFFFF)

  i = 0
  while i < rows

    j = 0
    while j < columns
      x = originX + j * deltaX
      y = originY + i * deltaY
      o = i % 2
      e = 1 - i % 2
      
      triangles.push new Triangle(getVector(x, y + deltaY * o), getVector(x + deltaX / 2, y + deltaY * e), getVector(x + deltaX, y + deltaY * o))
      triangles.push new Triangle(getVector(x + deltaX / 2, y + deltaY * e), getVector(x + deltaX, y + deltaY * o), getVector(x + 3 * deltaX / 2, y + deltaY * e))
      j++
    i++

resizeCanvas = ->
  canvas = renderer.view
  height = window.innerHeight
  width  = window.innerWidth
  renderer.resize width * ratio, height * ratio
  canvas.width = width * ratio
  canvas.height = height * ratio
  canvas.style.width = width
  canvas.style.height = ratio

  #window.addEventListener "DOMContentLoaded", init
  #alert "test"
  #init()

Template.indexMain.created = ->
  renderer = PIXI.autoDetectRenderer(window.innerWidth, window.innerHeight)
  ratio = window.devicePixelRatio or 1
  document.body.className += "landing"
  document.body.appendChild renderer.view
  #window.addEventListener "resize", resizeCanvas
  #window.addEventListener "resize", generateTriangles
  console.log "created"

Template.indexMain.rendered = ->
  resizeCanvas()
  generateTriangles()
  requestAnimationFrame draw

  $(window).on 'resize', ->
    resizeCanvas()
    generateTriangles()
  console.log "rendered"

Template.indexMain.destroyed = ->
  triangles = []
  renderer = undefined
