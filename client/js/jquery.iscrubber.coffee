###
  jQuery iScrubber plugin 1.1.0

  @preserve
  Created by Marco Martins
  https://github.com/skarface/iscrubber.git
###

$.fn.iscrubber = (customOptions) ->

  DIRECTION =
    HORIZONTAL: 'horizontal'
    VERTICAL: 'vertical'
    ###
      combined works either horizontal or vertical, depending on
      the direction from where the mouse entered the element
    ###
    COMBINED: 'combined'

  $.fn.iscrubber.defaultOptions =
    showItem: 1
    leaveToFirst: true
    direction: DIRECTION.HORIZONTAL

  ### Set the options ###
  options = $.extend({}, $.fn.iscrubber.defaultOptions, customOptions)

  ### Set starting active direction. This gets changed only by the combined option. ###
  activeDirection = options.direction

  ### scrub function ###
  scrub = (elements, itemToShow) ->
    if options.hideWithClass
      elements.addClass(options.hideWithClass)
      $(elements[itemToShow - 1]).removeClass(options.hideWithClass)
    else
      elements.css('display', 'none')
      $(elements[itemToShow - 1]).css('display', 'block')

  this.each ->
    $this = $(this)

    return if $this.data('iscrubber-enabled')
    $this.data('iscrubber-enabled', true)

    ### get elements ###
    elements = $this.find('li')

    ### set correct width from children and add minimal css require ###
    width = elements.first().width()
    height = elements.first().height()
    $this.width(width).height(height).css('padding', 0)

    numberOfChildren = $this.children().length

    ### get trigger width => (scrubber width / number of children) ###
    horizontalTrigger = width / numberOfChildren
    verticalTrigger = height / numberOfChildren

    ### show first element ###
    scrub(elements, options.showItem)

    lastX = null
    lastY = null
    originX = null
    originY = null
    directionX = true
    directionY = true

    ### bind event when mouse moves over scrubber ###
    $this.on 'mousemove.iscrubber', (e) ->
      if activeDirection is DIRECTION.COMBINED
        ###
          when activeDirection hasn't been yet set, determine it
          depending on the side from which the mouse entered the element
        ###
        horizontalDistanceToEdge = Math.min(Math.abs(e.pageX - $this.offset().left), Math.abs(e.pageX - $this.offset().left - width))
        verticalDistanceToEdge = Math.min(Math.abs(e.pageY - $this.offset().top), Math.abs(e.pageY - $this.offset().top - height))

        if (horizontalDistanceToEdge < verticalDistanceToEdge)
          activeDirection = DIRECTION.HORIZONTAL
        else
          activeDirection = DIRECTION.VERTICAL

        [lastX, lastY, originX, originY] = [e.pageX, e.pageY, e.pageX, e.pageY]

      if options.direction is DIRECTION.COMBINED
        ###
          also allow to change direction in between, if the user
          starts moving significantly in the opposite direction
        ###
        if activeDirection is DIRECTION.HORIZONTAL and Math.abs(e.pageY - originY) > height * 0.25
          activeDirection = DIRECTION.VERTICAL
          [originX, originY] = [e.pageX, e.pageY]

        else if activeDirection is DIRECTION.VERTICAL and Math.abs(e.pageX - originX) > width * 0.25
          activeDirection = DIRECTION.HORIZONTAL
          [originX, originY] = [e.pageX, e.pageY]

        ### determine which direction the user is moving right now ###
        [newDirectionX, newDirectionY] = [e.pageX > lastX, e.pageY > lastY]
         
        ### change origin when user reverses mouse movement direction ###
        originX = e.pageX if newDirectionX isnt directionX
        originY = e.pageY if newDirectionY isnt directionY

        ### save for next frame ###
        [lastX, lastY] = [e.pageX, e.pageY]
        [directionX, directionY] = [newDirectionX, newDirectionY]

      ### get the index of image to display on top ###
      switch activeDirection
        when DIRECTION.HORIZONTAL
          index = Math.ceil((e.pageX - $this.offset().left) / horizontalTrigger)
        when DIRECTION.VERTICAL
          index = Math.ceil((e.pageY - $this.offset().top) / verticalTrigger)

      index = Math.min(Math.max(index, 1), numberOfChildren)
      scrub(elements, index)

    $this.on 'mouseleave.iscrubber', ->
      scrub(elements, options.showItem) if options.leaveToFirst is true

      activeDirection = DIRECTION.COMBINED if options.direction is DIRECTION.COMBINED

