hslToRgb = (h, s, l) ->
  r = null
  g = null
  b = null
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

class Vector
  constructor: (@x, @y) ->
    @originX = x or 0
    @originY = y or 0
    @duration = null
    @start = null
    @deltaX = 0
    @deltaY = 0

  update: (time) =>
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

  toString = =>
    "#<Vector x: #{ @x }, y: #{ @y }>"

class Triangle
  constructor: (@background, @v0, @v1, @v2) ->
    @v0 ?= new Vector
    @v1 ?= new Vector
    @v2 ?= new Vector

    @graphics = new PIXI.Graphics

  draw: =>
    @graphics.clear()
    @graphics.beginFill @color(), 0.2
    @graphics.lineStyle 1 * @background.ratio, 0xFFFFFF, 0.4
    @graphics.moveTo @v0.x * @background.ratio, @v0.y * @background.ratio
    @graphics.lineTo @v1.x * @background.ratio, @v1.y * @background.ratio
    @graphics.lineTo @v2.x * @background.ratio, @v2.y * @background.ratio
    @graphics.endFill()

  area: =>
    Math.abs (@v0.x * @v1.y - @v1.x * @v0.y + @v1.x * @v2.y - @v2.x * @v1.y + @v2.x * @v0.y - @v0.x * @v2.y) / 2

  color: =>
    h = Math.min 1, (@area() / 100) / 360
    s = Math.min 1, (@area() / 100) / 100
    l = Math.min 1, (25 + @area() / 100) / 100
    #a = 0.2
    hslToRgb h, s, l

  toString: =>
    "#<Triangle v0: #{ @v0.toString() }, v1: #{ @v1.toString() }, v2: #{ @v2.toString() }>"

class @Background
  constructor: ->
    @renderer = PIXI.autoDetectRenderer window.innerWidth, window.innerHeight
    @computeRatio()

    @stage = null
    @triangles = {}
    @vectors = {}

  destroy: =>
    @renderer = null

    # To make sure memory is released
    @stage = null
    @triangles = {}
    @vectors = {}

  computeRatio: =>
    devicePixelRatio = window.devicePixelRatio or 1
    context = @renderer.gl or @renderer.context
    backingStoreRatio = context.webkitBackingStorePixelRatio or
                        context.mozBackingStorePixelRatio or
                        context.msBackingStorePixelRatio or
                        context.oBackingStorePixelRatio or
                        context.backingStorePixelRatio or 1

    @ratio = devicePixelRatio / backingStoreRatio

  render: =>
    @resizeView()
    @generateTriangles()

    requestAnimationFrame @draw

    @renderer.view

  resize: =>
    @resizeView()
    @generateTriangles()

    return # Make sure CoffeeScript does not return anything

  resizeView: =>
    return unless @renderer

    @computeRatio()

    width = window.innerWidth * @ratio
    height = window.innerHeight * @ratio

    @renderer.resize width, height

    $(@renderer.view).attr
      width: width
      height: height
    .css
      width: window.innerWidth
      height: window.innerHeight

  generateTriangles: =>
    return unless @renderer

    getVector = (args...) =>
      key = args.join ','
      @vectors[key] ?= new Vector args...
      @vectors[key]

    getTriangle = (args...) =>
      key = args.join ','
      [x1, y1, x2, y2, x3, y3] = args
      @triangles[key] ?= new Triangle @, getVector(x1, y1), getVector(x2, y2), getVector(x3, y3)
      @triangles[key]

    originX = -200
    originY = -200
    width   = window.innerWidth + 280
    height  = window.innerHeight + 280
    deltaX  = 140
    deltaY  = 52
    columns = Math.ceil(width / deltaX)
    rows    = Math.ceil(height / deltaY)

    @stage = new PIXI.Stage 0xFFFFFF

    for i in [0...rows]
      for j in [0...columns]
        x = originX + j * deltaX
        y = originY + i * deltaY
        o = i % 2
        e = 1 - i % 2

        triangle = getTriangle x, y + deltaY * o, x + deltaX / 2, y + deltaY * e, x + deltaX, y + deltaY * o
        @stage.addChild triangle.graphics

        triangle = getTriangle x + deltaX / 2, y + deltaY * e, x + deltaX, y + deltaY * o, x + 3 * deltaX / 2, y + deltaY * e
        @stage.addChild triangle.graphics

    return # To not have CoffeeScript return a result of for loop

  draw: (time) =>
    return unless @renderer

    vector.update time for key, vector of @vectors
    triangle.draw() for key, triangle of @triangles

    @renderer.render @stage

    requestAnimationFrame @draw
